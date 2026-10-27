"""Routes for user status checks"""


from flask import Blueprint, request
from utils.core.config import Settings
from utils.user_request_management.validation import clean
from utils.user_request_management.cookies import user_status
from utils.core.limits import limiter
from utils.db.mongodb import DB


settings = Settings()
user_status_bp = Blueprint('user_status', __name__, url_prefix='/api/user/status')
blocked_users_collection = DB['BlockedUsers']
users_collection = DB['Users']
logs_collection = DB['Logs']


@user_status_bp.route('/isblocked', methods=['POST'])
@limiter.limit(settings.ISBLOCKED_RATE_LIMIT)
def isblocked():
    """
        Checks if a user is blocked based on their email and cookie.

        Returns:
            str: "true" if the user is blocked, "false" if not,
            or "error" if cookie validation fails.
    """
    try:
        email, cookie, *_ = clean(email=request.json["email"],
                                  cookie=request.json["cookie"])
        if not email or not cookie:
            return "error", 200

        user, cookie_status = user_status(users_collection, blocked_users_collection,
                                          settings, email, cookie)
        if not user or not user["registered"] or not cookie_status:
            return "error", 200
        if blocked_users_collection.find_one({"email": email, "isBlocked": True}):
            return "true", 200
        return "false", 200
    except Exception as e:
        print(f"Specific error occurred: {e}")
        return "error", 500


@user_status_bp.route('/iscookievalid', methods=['POST'])
@limiter.limit(settings.ISCOOKIEVALID_RATE_LIMIT)
def iscookievalid():
    """
        Checks if the provided cookie is valid for the given email.

        Returns:
            str: "true" if the cookie is valid, "false" if not,
            or "error" if cookie validation fails.
    """
    try:
        email, cookie, *_ = clean(email=request.json["email"],
                                  cookie=request.json["cookie"])
        if not email or not cookie:
            return "error", 200

        user, cookie_status = user_status(users_collection, blocked_users_collection,
                                          settings, email, cookie)
        if user and user["registered"] and cookie_status:
            return "true", 200
        return "false", 200
    except Exception as e:
        print(f"Specific error occurred: {e}")
        return "error", 500


@user_status_bp.route('/userexists', methods=['POST'])
@limiter.limit(settings.USEREXISTS_RATE_LIMIT)
def userexists():
    """
        Checks if a user exists in the database based on their email and is registered.

        Returns:
            str: "true" if the user exists, "false" otherwise.
    """
    try:
        email = clean(email=request.json["email"])[0]
        if not email:
            return "false", 200

        user = users_collection.find_one({"email": email})
        if user:
            registration = user.get("registered")
            if not registration:
                return "false", 200
            return "true", 200
        return "false", 200
    except Exception as e:
        print(f"Specific error occurred: {e}")
        return "false", 500


@user_status_bp.route('/karma', methods=['POST'])
@limiter.limit(settings.KARMA_RATE_LIMIT)
def karma():
    """
    Returns the user's karma points or "0" if validation fails
    or "error" if cookie validation fails.
    """
    try:
        email, cookie, *_ = clean(email=request.json["email"],
                                  cookie=request.json["cookie"])
        if not email or not cookie:
            return "error", 200

        user, cookie_status = user_status(users_collection,
                                          blocked_users_collection,
                                          settings, email, cookie)
        if not user or not user["registered"]:
            return "0", 200
        if not cookie_status:
            return "error", 200
        return str(max(user["karma"], 0)), 200
    except Exception as e:
        print(f"Specific error occurred: {e}")
        return "error", 500
