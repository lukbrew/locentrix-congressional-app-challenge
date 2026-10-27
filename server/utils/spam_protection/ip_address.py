"""Tracks the IP address of users."""


from utils.db.mongodb import DB


def update_ip_address(user, ip_address):
    """
        Updates the user's IP address in the database.

        Args:
            user (dict): The user document from the database.
            ip_address (str): The new IP address to update.

        Returns:
            bool: True if the update was successful, False otherwise.
    """
    try:
        DB['Users'].update_one({"email": user['email']}, {"$set": {"ip_address": ip_address}})
        return True
    except Exception as e:
        print(f"Error updating IP address: {e}")
        return False
