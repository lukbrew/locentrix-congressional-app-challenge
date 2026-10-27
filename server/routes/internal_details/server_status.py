"""Status API routes"""


from flask import Blueprint
from utils.core.config import Settings
from utils.core.limits import limiter


settings = Settings()
server_status_bp = Blueprint('server_status', __name__, url_prefix='/api/status')


@server_status_bp.route('/', methods=['GET'])
@limiter.limit(settings.STATUS_RATE_LIMIT)
def status():
    """
        Status route for the Locentrix application.

        Returns:
            str: A message indicating that the application is running.
    """
    return "true", 200


@server_status_bp.route('/version', methods=['GET'])
@limiter.limit(settings.VERSION_RATE_LIMIT)
def version():
    """
        API version route for the Locentrix application (for breaking API changes).

        Returns:
            str: The version number of the application.
    """
    return settings.VERSION, 200


@server_status_bp.route('/appversion', methods=['GET'])
@limiter.limit(settings.APPVERSION_RATE_LIMIT)
def appversion():
    """
        App version route for the Locentrix application (app update checking).

        Returns:
            str: The version number of the application.
    """
    return settings.APPVERSION, 200
