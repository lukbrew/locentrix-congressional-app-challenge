"""
anticheat.py - A helper module for handling anti-cheat functions.
"""


from datetime import datetime, timedelta
from geopy.distance import geodesic


def calculate_block_distance_count(distance, incidents):
    """
        Calculates the number of incidents that are more than BLOCK_DISTANCE miles apart.

        Args:
            distance (float): The block distance in miles.
            incidents (list): A list of incident dictionaries containing coordinates.

        Returns:
            int: The count of incident pairs that are more than BLOCK_DISTANCE miles apart.
    """
    return sum(
        geodesic(
            (incident1["coordinates"][0], incident1["coordinates"][1]),
            (incident2["coordinates"][0], incident2["coordinates"][1])
        ).miles > distance
        for i, incident1 in enumerate(incidents)
        for incident2 in incidents[i + 1:]
    )


def get_recent_incidents(user, hours=6):
    """
        Retrieves recent incidents for a user within the last specified hours.

        Args:
            user (dict): The user document from the database.
            hours (int): The number of hours to look back for incidents.

        Returns:
            list: A list of incidents that occurred within the specified time frame.
    """
    now = datetime.utcnow()
    cutoff_time = now - timedelta(hours=hours)
    return [
        incident for incident in user.get("recent_incidents", [])
        if incident["time"] > cutoff_time
    ]
