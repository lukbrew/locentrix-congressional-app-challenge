"""Routes for retrieving pin data"""


from datetime import datetime, timedelta
from flask import Blueprint, request, Response
from utils.core.config import Settings
from utils.user_request_management.validation import clean
from utils.user_request_management.cookies import user_status
from utils.spam_protection.ip_address import update_ip_address
from utils.core.limits import limiter
from utils.db.mongodb import DB


settings = Settings()
retrieval_bp = Blueprint('retrieval', __name__, url_prefix='/api/pin/retrieval')
blocked_users_collection = DB['BlockedUsers']
users_collection = DB['Users']
pins_collection = DB['Pins']
logs_collection = DB['Logs']


@retrieval_bp.route('/pinrequest', methods=['POST'])
@limiter.limit(settings.PINREQUEST_RATE_LIMIT)
def pinrequest():
    """
        Requests all pins from the database for a user with the provided email and cookie.

        Returns:
            str: A string representation of pins if the request is successful,
                 "false" if validation fails or user is blocked,
                 or "error" if cookie validation fails.
    """
    try:
        email, cookie, _, _, _, ip = clean(email=request.json["email"],
                                           cookie=request.json["cookie"],
                                           ip_address=request.access_route[0])
        if not email or not ip:
            return "false", 200
        if not cookie:
            return "error", 200

        user, _ = user_status(users_collection, blocked_users_collection,
                              settings, email, cookie)
        if user and user["registered"]:
            update_ip_address(user, ip)
            pins = pins_collection.find({"reports": {"$gte": settings.MIN_REPORTS}})
            result = "\n".join(f"!{item_pin['type']}, "
                               f"{', '.join(map(str, item_pin['coordinates']))}"
                               for item_pin in pins)
            return Response(result if result else "false", mimetype="text/plain"), 200

        return "true", 200
    except Exception as e:
        print(f"Specific error occurred: {e}")
        return "false", 200


@retrieval_bp.route('/pinold', methods=['POST'])
@limiter.limit(settings.PINOLD_RATE_LIMIT)
def pinold():
    """
        Requests pins soon to be deleted from the database for a user with -
        the provided email and cookie.

        Returns:
            str: A string representation of old pins if the request is successful,
                 "false" if validation fails or user is blocked,
                 or "error" if cookie validation fails.
    """
    try:
        email, cookie, _, _, _, ip = clean(email=request.json["email"],
                                           cookie=request.json["cookie"],
                                           ip_address=request.access_route[0])
        if not email or not ip:
            return "false", 200
        if not cookie:
            return "error", 200

        user, _ = user_status(users_collection, blocked_users_collection,
                              settings, email, cookie)
        if user and user["registered"]:
            update_ip_address(user, ip)
            cutoff = datetime.utcnow() - timedelta(hours=settings.PIN_START_AGING
                                                   ) + timedelta(seconds=10)
            pins = pins_collection.find({"reports": {"$lte": 0}, "update_date": {"$lt": cutoff}})
            result = "\n".join(f"!{item_pin['type']}, "
                               f"{', '.join(map(str, item_pin['coordinates']))}"
                               for item_pin in pins)
            return Response(result if result else "false", mimetype="text/plain"), 200

        return "true", 200
    except Exception as e:
        print(f"Specific error occurred: {e}")
        return "false", 500


@retrieval_bp.route('/pinnew', methods=['POST'])
@limiter.limit(settings.PINNEW_RATE_LIMIT)
def pinnew():
    """
        Requests new pins from the database for a user with the provided email and cookie.

        Returns:
            str: A string representation of new pins if the request is successful,
                 "false" if validation fails or user is blocked,
                 or "error" if cookie validation fails.
    """
    try:
        email, cookie, _, _, _, ip = clean(email=request.json["email"],
                                           cookie=request.json["cookie"],
                                           ip_address=request.access_route[0])
        if not email:
            return "false", 200
        if not cookie:
            return "error", 200

        user, _ = user_status(users_collection, blocked_users_collection,
                              settings, email, cookie)
        if user and user["registered"]:
            update_ip_address(user, ip)
            cutoff = datetime.utcnow() - timedelta(seconds=10)
            pins = pins_collection.find({"creation_date": {"$gte": cutoff},
                                         "reports": {"$gte": settings.MIN_REPORTS}})
            result = "\n".join(f"!{item_pin['type']}, "
                               f"{', '.join(map(str, item_pin['coordinates']))}"
                               for item_pin in pins)
            return Response(result if result else "false", mimetype="text/plain"), 200

        return "true"
    except Exception as e:
        print(f"Specific error occurred: {e}")
        return "false"
