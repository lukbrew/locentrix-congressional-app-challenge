"""
config.py - A helper module for handling configuration variables.
"""


from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    """
    A dataclass for storing configuration variables.
    """

    # VARIABLES
    # Cleanup date cutoffs (in days)
    BLOCKED_USER_CLEANUP = 30
    CREATED_USER_CLEANUP = 7
    LOG_CLEANUP = 60
    # (in hours)
    RECENT_INCIDENT_CLEANUP = 2

    # Interval between cleanup checks (in seconds)
    BLOCKED_USERS_CLEANUP_INTERVAL = 604800
    OLD_PIN_TTL = 3600

    # Pin aging interval (in hours)
    PIN_START_AGING = 2

    # Anticheat triggers (in miles)
    BLOCK_DISTANCE = 300
    TRIGGER_DISTANCE = 100

    # Cookie expiration time (in hours)
    COOKIE_TTL = 6

    # Minimum reports to return pin on request
    MIN_REPORTS = 5

    # Messages
    MESSAGE = "Welcome!"
    UPDATEMESSAGE = []
    """
    Format per message:
    {
    "Message": "Message to display",
    "MinVersion": "Minimum app version to display message",
    "MaxVersion": "Maximum app version to display message,
    "Importance": "Importance of message (1-infinity, 1 being most important)"
    }
    """

    # EMAIL CONTENTS:
    # Registration email:
    REGISTRATION_EMAIL_BODY = "Welcome to Locentrix! You are now registered."
    REGISTRATION_EMAIL_SUBJECT = "Welcome!"
    # Verification email:
    VERIFICATION_EMAIL_SUBJECT = "Verification Code"
    # Account deletion email:
    DELETION_EMAIL_SUBJECT = "Account Deletion"
    DELETION_EMAIL_BODY = ("We are sorry to see you go. Your account has been "
                           "successfully deleted, but limited data may be temporarily "
                           "retained for security purposes.")

    # Flask Rate Limits
    APPVERSION_RATE_LIMIT = "5 per minute"
    ISBLOCKED_RATE_LIMIT = "5 per minute"
    ISCOOKIEVALID_RATE_LIMIT = "5 per minute"
    KARMA_RATE_LIMIT = "5 per minute"
    MESSAGE_RATE_LIMIT = "2 per minute"
    PIN_RATE_LIMIT = "2 per minute"
    PINNEW_RATE_LIMIT = "12 per minute"
    PINOLD_RATE_LIMIT = "12 per minute"
    PINREQUEST_RATE_LIMIT = "5 per minute"
    REGISTER_RATE_LIMIT = "2 per minute"
    STATUS_RATE_LIMIT = "20 per minute"
    UPDATEMESSAGE_RATE_LIMIT = "5 per minute"
    USEREXISTS_RATE_LIMIT = "5 per minute"
    USRREMOVE_RATE_LIMIT = "2 per minute"
    USRREMOVEVERIFY_RATE_LIMIT = "4 per minute"
    VERIFY_RATE_LIMIT = "4 per minute"
    VERSION_RATE_LIMIT = "5 per minute"
    WEB_RATE_LIMIT = "60 per minute"

    # Versions
    VERSION = "1"
    APPVERSION = "1.0.0"

    # MongoDB Settings
    MAX_RETRIES = 10
