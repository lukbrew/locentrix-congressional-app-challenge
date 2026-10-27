"""
logging.py - A helper module for basic logging.
"""


from datetime import datetime


def log_action(logs_collection, email, action):
    """
        Logs a user action to the database.

        Args:
            logs_collection (pymongo.collection.Collection): The collection to
                                                             store logs in.
            email (str): The email address of the user performing the action.
            action (str): A description of the action being logged.

        Returns:
            None
    """
    try:
        logs_collection.insert_one({
            "email": email,
            "action": action,
            "time": datetime.utcnow(),
        })
    except Exception as e:
        print(f"Specific error occurred: {e}")
