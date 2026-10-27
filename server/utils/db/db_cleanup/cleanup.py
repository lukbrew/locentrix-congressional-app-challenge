"""
cleanup.py - A module for handling periodic database cleanup tasks and pin expiration.
"""


from datetime import datetime, timedelta


def clean_old_pins(stopping_event, pins_collection, clean_pins_lock,
                   old_pin_ttl, pin_start_aging):
    """
        Controls pin expiration and cleanup.
        Deletes pins that have zero reports or fewer.
        Checks remaining pins that are older than 2 hours ONLY and removes -
        one report from the counter.
        Then updates the report date (for the correct counter-decrease rate).

        Args:
            stopping_event (threading.Event): An event to signal when to stop the cleanup thread.
            pins_collection (pymongo.collection.Collection): The MongoDB collection for pins.
            clean_pins_lock (threading.Lock): A lock to ensure thread-safe operations
                                              on the pins collection.
            old_pin_ttl (int): Time-to-live in seconds for old pins before cleanup.
            pin_start_aging (int): How frequently pins age.
    """
    while not stopping_event.is_set():
        try:
            with clean_pins_lock:
                pins_collection.delete_many({"reports": {"$lte": 0}})
                cutoff = datetime.utcnow() - timedelta(hours=pin_start_aging)
                pins_collection.update_many({"update_date": {"$lt": cutoff}},
                                            {"$inc": {"reports": -1},
                                             "$set": {"update_date": datetime.utcnow()}})
        except Exception as e:
            print(f"Specific error occurred: {e}")
        stopping_event.wait(old_pin_ttl)


def clean_blocked_users(stopping_event, blocked_users_collection, users_collection,
                        logs_collection, blocked_user_cleanup, created_user_cleanup,
                        log_cleanup, cleanup_interval):
    """
        Cleans up blocked users and old user registrations from the database.

        Args:
            stopping_event (threading.Event): An event to signal when to stop the cleanup thread.
            blocked_users_collection (pymongo.collection.Collection): The MongoDB collection for
                                                                      blocked users.
            users_collection (pymongo.collection.Collection): The MongoDB collection for users.
            logs_collection (pymongo.collection.Collection): The MongoDB collection for logs.
            blocked_user_cleanup (int): How long to keep blocked users in the database.
            created_user_cleanup (int): How long to keep unregistered users in the database.
            log_cleanup (int): How long to keep logs in the database.
            cleanup_interval (int): How often to run the cleanup task.

    """
    while not stopping_event.is_set():
        try:
            cutoff_blocked_users = datetime.utcnow() - timedelta(days=blocked_user_cleanup)
            blocked_users_collection.delete_many({"isDeleted": {"$lt": cutoff_blocked_users}})

            cutoff_created_users = datetime.utcnow() - timedelta(days=created_user_cleanup)
            users_collection.delete_many({
                "time": {"$lt": cutoff_created_users},
                "registered": False
            })

            cutoff_logs = datetime.utcnow() - timedelta(days=log_cleanup)
            logs_collection.delete_many({"time": {"$lt": cutoff_logs}})
        except Exception as e:
            print(f"Specific error occurred: {e}")
        stopping_event.wait(cleanup_interval)
