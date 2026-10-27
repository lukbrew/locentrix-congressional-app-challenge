"""User-facing pages"""


from flask import Blueprint
from utils.core.config import Settings
from utils.core.limits import limiter


settings = Settings()
user_facing_bp = Blueprint('user_facing', __name__)


@user_facing_bp.route('/', methods=['GET'])
@limiter.limit(settings.WEB_RATE_LIMIT)
def home():
    """
        Home route for the Locentrix application.

        Returns:
            str: A welcome message.
    """
    return "Welcome to locentrix! This will have information about us soon.", 200


@user_facing_bp.route('/terms', methods=['GET'])
@limiter.limit(settings.WEB_RATE_LIMIT)
def terms():
    """
        Terms of use route for the Locentrix application.

        Returns:
            str: A placeholder message indicating that terms of use will be available soon.
    """
    return "Welcome to locentrix! This will have the terms of use soon!", 200
