"""
    validation.py - A helper module for handling input validation functions.
"""


import re
import ipaddress
import bleach


def is_valid_version(version):
    """
        Validates if the given version string is in a proper format (e.g., "1.0.0").

        Args:
            version (str): The version string to validate.

        Returns:
            bool: True if the version string is valid, False otherwise.
    """
    version_regex = r'^\d+\.\d+\.\d+$'
    version = bleach.clean(str(version)).strip() if version else None
    if version and re.fullmatch(version_regex, version):
        return version
    return False


def is_valid_email(email):
    """
        Validates if the given email address is in a proper format.

        Args:
            email (str): The email address to validate.

        Returns:
            bool: True if the email address is valid, False otherwise.
    """
    email_regex = r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$'
    return re.match(email_regex, email) is not None


def is_valid_coordinates(coordinates):
    """
        Validates if the given coordinates are in a proper format.

        Args:
            coordinates (str): The coordinates to validate in "lat,lon" format.

        Returns:
            bool: True if the coordinates are valid, False otherwise.
        """
    try:
        lat, lon = map(float, coordinates.split(","))
        return -90 <= lat <= 90 and -180 <= lon <= 180
    except ValueError:
        return False


def is_valid_code(code):
    """
        Validates if the given code is a 6-digit number.

        Args:
            code (str): The code to validate.

        Returns:
            bool: True if the code is valid, False otherwise.
    """
    regex_code = r'^\d{6}$'
    return re.match(regex_code, code) is not None


def is_valid_cookie(cookie):
    """
        Validates if the given cookie is a 6-digit number.

        Args:
            cookie (str): The cookie to validate.

        Returns:
            bool: True if the cookie is valid, False otherwise.
    """
    regex_cookie = r'^\d{6}$'
    return re.match(regex_cookie, cookie) is not None


def is_valid_pin_type(pin_type):
    """
        Validates if the given pin type is one of the allowed types.

        Args:
            pin_type (str): The pin type to validate.

        Returns:
            bool: True if the pin type is valid, False otherwise.
    """

    allowed_pin_types = ['Construction', 'Crash', 'Traffic',
                         'Damage', 'Debris', 'Slippery',
                         'Police', 'Other']

    return pin_type in allowed_pin_types


def is_valid_ip(address):
    """
        Validate if the given address is a valid IPv4 or IPv6 address.
    Args:
        address: str, The IP address to validate.

    Returns:
        bool: True if the address is valid, False otherwise.
    """
    try:
        ipaddress.ip_address(address)
        return True
    except ValueError:
        return False


def clean(email=None, cookie=None, code=None, coordinates=None, pin_type=None, ip_address=None):
    """
        Cleans and validates input parameters.

        Args:
            email (str): The email address to validate.
            cookie (str): The cookie to validate.
            code (str): The verification code to validate.
            coordinates (str): The coordinates to validate in "lat,lon" format.
            pin_type (str): The type of pin to validate.
            ip_address (str): The IP address to validate.

        Returns:
            tuple: A tuple containing cleaned and validated inputs or False if invalid.
    """
    inputs = [email, cookie, code, coordinates, pin_type, ip_address]
    validators = [is_valid_email, is_valid_cookie,
                  is_valid_code, is_valid_coordinates, is_valid_pin_type,
                  is_valid_ip]

    return_list = [
        bleach.clean(str(value)) if value and (
                validator is None or validator(bleach.clean(str(value)))) else False
        for value, validator in zip(inputs, validators)
    ]

    return tuple(return_list)
