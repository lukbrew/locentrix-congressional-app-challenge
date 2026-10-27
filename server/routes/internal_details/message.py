"""API routes for messages displayed"""


from flask import Blueprint, request
from utils.core.config import Settings
from utils.core.limits import limiter
from utils.user_request_management.validation import is_valid_version


settings = Settings()
message_bp = Blueprint('internal_details', __name__, url_prefix='/api/message')


@message_bp.route('/terms', methods=['GET'])
@limiter.limit(settings.WEB_RATE_LIMIT)
def api_terms():
    """
        Terms of use route for the Locentrix application.

        Returns:
            str: A placeholder message indicating that terms of use will be available soon.
    """
    return "Welcome to locentrix! This will have the terms of use soon!", 200


@message_bp.route('/', methods=['GET'])
@limiter.limit(settings.MESSAGE_RATE_LIMIT)
def message():
    """
        Message route for the Locentrix application.

        Returns:
            str: The message from the settings dataclass or "false" if not set.
    """
    try:
        intro_message = settings.MESSAGE
        if not intro_message:
            return "false", 200
        return intro_message, 200
    except Exception as e:
        print(f"Specific error occurred: {e}")
        return "false", 500


@message_bp.route('/update', methods=['POST'])
@limiter.limit(settings.UPDATEMESSAGE_RATE_LIMIT)
def update_message():
    """
    Provides a message depending on provided app version.

    Returns:
        str: The message from the settings dataclass for the version or "false" if none.
    """
    try:
        version = is_valid_version(request.json["version"])
        if version and settings.UPDATEMESSAGE:
            potential_messages = []
            for message_item in settings.UPDATEMESSAGE:
                if message_item["MinVersion"] <= version <= message_item["MaxVersion"]:
                    potential_messages.append(message_item)
            if potential_messages:
                if len(potential_messages) == 1:
                    return potential_messages[0]["Message"], 200
                potential_messages.sort(key=lambda x: x["Importance"])
                return potential_messages[0]["Message"], 200
        return "false", 200
    except Exception as e:
        print(f"Specific error occurred: {e}")
        return "false", 500
