"""
app.py - A Flask application that functions as the backend for the Locentrix app.
A "pin" is an internal term for an incident report.
"""


# Built-in packages
import sys
import signal
# Installed packages
from flask import Flask
# Custom package
from utils.core.check_dotenv import check_env_vars


# Check for the existence of all necessary environment variables.
check_env_vars()


# Custom project packages
from utils.core.config import Settings
from utils.db.mongodb import DB


settings = Settings()

# Flask setup
app = Flask(__name__)
app.config.from_prefixed_env()
app.config.setdefault('RATELIMIT_STORAGE_URI', app.config.get('DATABASE_URL'))

# MongoDB connection
if DB is None:
    print("Failed to connect to MongoDB")
    sys.exit()


# Import necessary utilities and Flask blueprints
from utils.core.limits import limiter
from utils.db.db_cleanup.threads import shutdown_handler
from routes.user_facing import user_facing_bp
from routes.internal_details.message import message_bp
from routes.internal_details.server_status import server_status_bp
from routes.user_management.addition import addition_bp
from routes.user_management.removal import removal_bp
from routes.user_management.user_status import user_status_bp
from routes.pin_management.reporting import reporting_bp
from routes.pin_management.retrieval import retrieval_bp


# Flask routes
app.register_blueprint(user_facing_bp)
app.register_blueprint(message_bp)
app.register_blueprint(server_status_bp)
app.register_blueprint(addition_bp)
app.register_blueprint(removal_bp)
app.register_blueprint(user_status_bp)
app.register_blueprint(reporting_bp)
app.register_blueprint(retrieval_bp)

# Start rate limiter
limiter.init_app(app)

# Register the shutdown handler for SIGINT and SIGTERM
signal.signal(signal.SIGINT, shutdown_handler)
signal.signal(signal.SIGTERM, shutdown_handler)

if __name__ == '__main__':
    app.run(debug=False)
