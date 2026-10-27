"""User deletion routes"""


from datetime import datetime
from flask import Blueprint, request
from utils.core.config import Settings
from utils.user_request_management.validation import clean
from utils.user_request_management.user_verif import (generate_code,
                                                      hash_code,
                                                      verify_hashed_code)
from utils.spam_protection.ip_address import update_ip_address
from utils.core.email import send_email
from utils.core.limits import limiter
from utils.db.logging import log_action
from utils.db.mongodb import DB


settings = Settings()
removal_bp = Blueprint('removal', __name__, url_prefix='/api/user/removal')
blocked_users_collection = DB['BlockedUsers']
users_collection = DB['Users']
logs_collection = DB['Logs']


@removal_bp.route('/usrremove', methods=['POST'])
@limiter.limit(settings.USRREMOVE_RATE_LIMIT)
def usrremove():
    """
        Initiates the user removal process by sending a verification code to the user's email.

        Returns:
            str: "true" if the email is valid and the user exists, "false" otherwise.
    """
    try:
        email, _, _, _, _, ip = clean(email=request.json["email"],
                                      ip_address=request.access_route[0])

        if not email:
            return "false", 200
        user = users_collection.find_one({"email": email})
        if user and ip:
            update_ip_address(user, ip)
            code = generate_code()
            hashed_code = hash_code(code)
            send_email(email, settings.VERIFICATION_EMAIL_SUBJECT,
                       f"Your verification code to delete your email is: {code}")
            users_collection.update_one({"email": email},
                                        {"$set": {"deletion_code": hashed_code}})
            log_action(logs_collection, email, "usrremove")
            return "true", 200
        return "false", 200
    except Exception as e:
        print(f"Specific error occurred: {e}")
        return "false", 500


@removal_bp.route('/usrremoveverify', methods=['POST'])
@limiter.limit(settings.USRREMOVEVERIFY_RATE_LIMIT)
def usrremoveverify():
    """
        Verifies the user's request to remove their -
        account using the provided email and verification code.

        Returns:
            str: "true" if verification is successful and user is removed, "false" otherwise.
    """
    try:
        email, _, code, *_ = clean(email=request.json["email"],
                                   code=request.json["code"])

        if not email or not code:
            return "false", 200
        user = users_collection.find_one({"email": email})
        if user and user.get('deletion_code'):
            if verify_hashed_code(user['deletion_code'], code):
                users_collection.delete_one({"email": email})
                blocked_users_collection.update_one(
                    {"email": email},
                    {"$set": {"isDeleted": datetime.utcnow()}})
                send_email(email,
                           settings.DELETION_EMAIL_SUBJECT,
                           settings.DELETION_EMAIL_BODY)
                log_action(logs_collection, email, "usrremoveverif_true")
                return "true", 200
        log_action(logs_collection, email, "usrremoveverif_false")
        return "false", 200
    except Exception as e:
        print(f"Specific error occurred: {e}")
        return "false", 500
