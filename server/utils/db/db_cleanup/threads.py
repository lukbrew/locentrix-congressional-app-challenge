"""
threads.py - Handle background threads.
"""


import sys
import threading
from threading import Lock
from utils.db.db_cleanup.cleanup import clean_old_pins, clean_blocked_users
from utils.core.config import Settings
from utils.db.mongodb import DB


settings = Settings()

blocked_users_collection = DB['BlockedUsers']
users_collection = DB['Users']
pins_collection = DB['Pins']
logs_collection = DB['Logs']

clean_pins_lock = Lock()
stop_event = threading.Event()

# Start the cleanup threads
blocked_users_cleanup_thread = threading.Thread(
    target=clean_blocked_users,
    args=(stop_event, blocked_users_collection, users_collection,
          logs_collection, settings.BLOCKED_USER_CLEANUP,
          settings.CREATED_USER_CLEANUP, settings.LOG_CLEANUP,
          settings.BLOCKED_USERS_CLEANUP_INTERVAL),
    daemon=True)
blocked_users_cleanup_thread.start()


cleanup_thread = threading.Thread(
    target=clean_old_pins,
    args=(stop_event, pins_collection, clean_pins_lock,
          settings.OLD_PIN_TTL, settings.PIN_START_AGING),
    daemon=True
)
cleanup_thread.start()


# Graceful shutdown handler
def shutdown_handler(signum, frame):
    """
        Handles graceful shutdown of the application by stopping threads and cleaning up resources.

        Args:
            signum (int): The signal number that triggered the shutdown.
            frame (frame): The current stack frame.
    """
    stop_event.set()
    blocked_users_cleanup_thread.join(timeout=60)
    cleanup_thread.join(timeout=60)
    print(signum)
    print(frame)
    sys.exit(0)
