"""
trust_scoring.py - A module for calculating and
                   returning a user's trust score.
"""


from datetime import datetime


def update_trust_score(users_collection=None, receiving_email=None,
                       value=None, reporter_email=None):
    """
    Updates and returns the trust score of a user based on
    another user's trust score and the value of the interaction.
    Trust scores are capped at 4.5 points. The age of the account
    also is taken into consideration. The age score is capped at
    1.5 points - reached around three years of age.
    Args:
        users_collection: The MongoDB collection containing user data.
        receiving_email: str, The email address of the user receiving the trust score change.
        value: float, The value of the interaction (positive or negative).
        reporter_email: str, The email address of the user affecting the trust score.

    Returns:

    """
    if not users_collection or not receiving_email or not value:
        return None

    receiving_user = users_collection.find_one({"email": receiving_email})
    receiving_score = receiving_user['trust_score']

    receiving_agescore = datetime.utcnow() - receiving_user['time']
    receiving_agescore = int(receiving_agescore.days / 7) * 0.01

    if value > 0 and receiving_score == 4.5:
        return receiving_score + receiving_agescore

    if reporter_email:
        reporter_user = users_collection.find_one({"email": reporter_email})
        reporter_score = reporter_user['trust_score']
        reporter_agescore = datetime.utcnow() - reporter_user['time']
        reporter_agescore = int(reporter_agescore.days / 7) * 0.01
        reporter_agescore = min(reporter_agescore, 1.5)
        reporter_score += reporter_agescore
        receiving_score += value * min(max(reporter_score, 0), 2.5)
    else:
        receiving_score += value

    receiving_score = min(receiving_score, 4.5)

    users_collection.update_one({"email": receiving_email},
                                {"$set": {"trust_score": float(receiving_score)}})
    score = receiving_score + receiving_agescore
    if score < 0:
        return 0
    return score


def retrieve_trust_score(users_collection, email):
    """
    Retrieves and returns the trust score of a user.
    Args:
        users_collection: The MongoDB collection containing user data.
        email: str, The email address of the user.

    Returns:

    """
    user = users_collection.find_one({"email": email})
    trust_score = user['trust_score']
    agescore = datetime.utcnow() - user['time']
    agescore = int(agescore.days / 7) * 0.01
    agescore = min(agescore, 1.5)
    score = trust_score + agescore
    score = max(score, 0)
    return score
