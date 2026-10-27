"""
check_dotenv.py - A helper module for checking the .env file for all vars.
"""


import os
from dotenv import load_dotenv


def check_env_vars():
    """
        Checks if all required environment variables are set in the .env file.

        Raises:
            EnvironmentError: If any required environment variable is missing.
    """
    load_dotenv()

    required_env_vars = ['FLASK_DATABASE_URL',
                         'FLASK_EMAIL_ADDRESS',
                         'FLASK_EMAIL_PASS',
                         'FLASK_SMTP_PORT',
                         'FLASK_SMTP_SERVER']
    for var in required_env_vars:
        if not os.getenv(var):
            print(f"Missing required environment variable: {var}")
            raise EnvironmentError(f"Missing required environment variable: {var}")
    try:
        int(os.getenv('FLASK_SMTP_PORT'))
    except:
        raise EnvironmentError("FLASK_SMTP_PORT must be an integer")  # pylint: disable=raise-missing-from
