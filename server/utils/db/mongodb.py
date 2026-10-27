"""
mongodb.py - Init MongoDB connection.
"""


import os
from time import sleep
import certifi
import pymongo
from pymongo import MongoClient, errors
from dotenv import load_dotenv
from utils.core.config import Settings


load_dotenv()
settings = Settings()

DB = None
retry_count = 0  # pylint: disable=invalid-name
# Attempts database connection with retries on timeout
while DB is None and retry_count < settings.MAX_RETRIES:
    try:
        client = MongoClient(os.getenv("FLASK_DATABASE_URL"),
                             serverSelectionTimeoutMS=5000,
                             tlsCAFile=certifi.where())
        DB = client.get_database()
        if DB is not None:
            # Init collections
            users_collection = DB['Users']
            pins_collection = DB['Pins']
            logs_collection = DB['Logs']
            blocked_users_collection = DB['BlockedUsers']

            # Create indexes for frequently queried fields
            pins_collection.create_index([("coordinates", pymongo.ASCENDING)])
            pins_collection.create_index("type")
            pins_collection.create_index("reports")
            pins_collection.create_index("update_date")
            pins_collection.create_index("creation_date")
    except errors.ServerSelectionTimeoutError:
        retry_count += 1
        sleep(30)
