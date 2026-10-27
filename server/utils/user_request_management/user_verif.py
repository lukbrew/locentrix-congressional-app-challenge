"""
    user_verif.py - A helper module for handling some user verification functions.
"""


import random
import hashlib


def generate_code():
    """
        Generates a random six digit code.

        Returns:
            str: A six-digit code as a string.
    """
    return str(random.randint(100000, 999999))


def hash_code(code):
    """
        Hashes the given code using SHA-256.

        Args:
            code (str): The code to hash.

        Returns:
            str: The SHA-256 hash of the code.
        """
    return hashlib.sha256(code.encode()).hexdigest()


def verify_hashed_code(hashed_code, code):
    """
        Verifies if the given hashed code matches the hash of the provided code.

        Args:
            hashed_code (str): The hashed code to verify against.
            code (str): The code to hash and compare.

        Returns:
            bool: True if the hashes match, False otherwise.
    """
    return hashed_code == hash_code(code)
