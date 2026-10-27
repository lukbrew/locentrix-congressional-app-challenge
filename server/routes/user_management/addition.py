"""User registration and verification routes"""


from datetime import datetime, timedelta
from flask import Blueprint, request
from utils.core.config import Settings
from utils.user_request_management.validation import clean
from utils.user_request_management.user_verif import (generate_code,
                                                      hash_code,
                                                      verify_hashed_code)
from utils.user_request_management.cookies import user_status
from utils.spam_protection.ip_address import update_ip_address
from utils.core.email import send_email
from utils.core.limits import limiter
from utils.db.logging import log_action
from utils.db.mongodb import DB


settings = Settings()
addition_bp = Blueprint('addition', __name__, url_prefix='/api/user/addition')
blocked_users_collection = DB['BlockedUsers']
users_collection = DB['Users']
logs_collection = DB['Logs']


@addition_bp.route('/register', methods=['POST'])
@limiter.limit(settings.REGISTER_RATE_LIMIT)
def register():
    """
        Registers a user with the provided email address.

        Returns:
            str: "true" if registration is successful,
            "false" if the email is invalid or user is blocked.
    """
    try:
        email, _, _, _, _, ip = clean(email=request.json["email"],
                                      ip_address=request.access_route[0])
        if not email or not ip:
            return "false", 200

        blocked_user = blocked_users_collection.find_one({"email": email})
        if not blocked_user:
            blocked_users_collection.insert_one({"email": email,
                                                 "isBlocked": False,
                                                 "isDeleted": None})

        # Check if the user is blocked
        if blocked_user and blocked_user['isBlocked']:
            return "false", 200

        code = generate_code()
        hashed_code = hash_code(code)
        send_email(email, settings.VERIFICATION_EMAIL_SUBJECT,
                   f"Welcome to Locentrix! Your verification code is: {code}")
        if users_collection.find_one({"email": email}):
            users_collection.update_one({"email": email}, {"$set": {"code": hashed_code}})
            log_action(logs_collection, email, "old")
        else:
            users_collection.insert_one({
                "email": email,
                "code": hashed_code,
                "deletion_code": False,
                "registered": False,
                "time": datetime.utcnow(),
                "cookie": hash_code(generate_code()),
                "ttl": datetime.utcnow() + timedelta(days=31),
                "karma": 0,
                "trust_score": 0.5,
                "ip_address": ip,
            })
            log_action(logs_collection, email, "new")
        return "true", 200
    except Exception as e:
        print(f"Specific error occurred: {e}")
        return "false", 500


@addition_bp.route('/verify', methods=['POST'])
@limiter.limit(settings.VERIFY_RATE_LIMIT)
def verify():
    """
        Verifies a user's registration using the provided email and verification code.

        Returns:
            str: A cookie if verification is successful,
            "false" if verification fails or user is blocked.
    """
    try:
        email, _, code, _, _, ip = clean(email=request.json["email"],
                                         code=request.json["code"],
                                         ip_address=request.access_route[0])
        if not email or not code or not ip:
            return "false", 200

        blocked_user = blocked_users_collection.find_one({"email": email})
        if blocked_user and blocked_user['isBlocked']:
            return "false", 200

        is_registered = users_collection.find_one({"email": email,
                                                   "registered": True})
        user, _ = user_status(users_collection, blocked_users_collection, settings, email, None)
        if user:
            update_ip_address(user, ip)
            if verify_hashed_code(user['code'], code):
                cookie = generate_code()
                users_collection.update_one({"email": email},
                                            {"$set": {"registered": True,
                                                      "code": hash_code(generate_code()),
                                                      "cookie": hash_code(cookie),
                                                      "ttl": datetime.utcnow() + timedelta(days=1)}
                                             })
                log_action(logs_collection, email, "verif_true")
                if not is_registered:
                    send_email(email, settings.REGISTRATION_EMAIL_SUBJECT,
                               settings.REGISTRATION_EMAIL_BODY)
                return cookie, 200
        log_action(logs_collection, email, "verif_false")
        return "false", 200
    except Exception as e:
        print(f"Specific error occurred: {e}")
        return "false", 500
