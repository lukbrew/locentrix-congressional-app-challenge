"""
cookies.py - A helper module for handling cookie-related functions.
"""


from datetime import datetime, timedelta
# Internal imports
from utils.user_request_management.validation import clean
from utils.user_request_management.user_verif import generate_code, hash_code


def good_cookie(users_collection, settings, email, cookie):
    """
        Validates if the provided email and cookie combination is valid and checks the cookie's TTL.

        If the cookie is valid but expired, generates a new cookie and updates the user's record.

        Args:
            users_collection: The MongoDB collection containing user data.
            settings: The app settings object.
            email (str): The email address of the user.
            cookie (str): The cookie to validate.

        Returns:
            bool or str: Returns True if the cookie is valid and not expired.
                         Returns a new cookie (str) if the old cookie is expired but valid.
                         Returns False if the cookie is invalid or an error occurs.
    """
    try:
        _, cookie, *_ = clean(cookie=cookie)
        if not cookie:
            return False
        hashed_cookie = hash_code(cookie)
        user = users_collection.find_one({"email": email})
        if user and user['cookie'] == hashed_cookie:
            ttl = user['ttl']
            if datetime.utcnow() < ttl:
                return True
            new_cookie = generate_code()
            ttl = datetime.utcnow() + timedelta(hours=settings.COOKIE_TTL)
            users_collection.find_one_and_update(
                {"cookie": hashed_cookie},
                {"$set": {"cookie": hash_code(new_cookie), "ttl": ttl}}
            )
            return new_cookie
        return False
    except Exception as e:
        print(f"Specific error occurred: {e}")
        return False


def user_status(users_collection, blocked_users_collection, settings, email, cookie):
    """
        Checks the status of a user based on their email and cookie.
        Args:
            users_collection: The MongoDB collection containing user data.
            blocked_users_collection: The MongoDB collection containing user data
                                      on if a user is blocked.
            settings: The app settings object.
            email (str): The email address of the user.
            cookie (str or None): The cookie to validate.

        Returns:
            dict: A dict containing the user document if found and valid,
            bool or str: The cookie status (True, False, or "error").
    """
    blocked_user = blocked_users_collection.find_one({"email": email})
    if blocked_user and blocked_user['isBlocked']:
        return False, None
    cookie_status = None
    if cookie:
        cookie_status = good_cookie(users_collection,
                                    settings,
                                    email,
                                    cookie)
        if cookie_status is False:
            return None, "error"
    user = users_collection.find_one({"email": email})
    return user, cookie_status
