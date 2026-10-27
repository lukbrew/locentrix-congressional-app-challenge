"""Routes for reporting pin data"""


from datetime import datetime, timedelta
from flask import Blueprint, request
import pymongo
from utils.core.config import Settings
from utils.user_request_management.validation import clean
from utils.user_request_management.cookies import user_status
from utils.spam_protection.trust_scoring import (update_trust_score,
                                                 retrieve_trust_score)
from utils.spam_protection.anticheat import (calculate_block_distance_count,
                                             get_recent_incidents)
from utils.core.limits import limiter
from utils.db.logging import log_action
from utils.db.mongodb import DB


settings = Settings()
reporting_bp = Blueprint('reporting', __name__, url_prefix='/api/pin/reporting')
blocked_users_collection = DB['BlockedUsers']
users_collection = DB['Users']
pins_collection = DB['Pins']
logs_collection = DB['Logs']


@reporting_bp.route('/pin', methods=['POST'])
@limiter.limit(settings.PIN_RATE_LIMIT)
def pin():
    """
        Adds a pin to the database with the provided email, coordinates, and pin type.

        Returns:
            str: "true" if the pin is added successfully,
            "false" if validation fails or user is blocked
            or "error" if cookie validation fails.
    """
    response = "false"
    try:
        email, cookie, _, coordinates, pin_type, ip = clean(
            email=request.json["email"],
            cookie=request.json["cookie"],
            coordinates=request.json["coordinates"],
            pin_type=request.json["pin_type"],
            ip_address=request.access_route[0]
        )

        if not email or not coordinates or not pin_type or not ip:
            return response, 200
        if not cookie:
            return "error", 200

        user, cookie_status = user_status(users_collection, blocked_users_collection,
                                          settings, email, cookie)
        if not (user and user["registered"] and cookie_status and cookie_status != "error"):
            return response, 200

        coords = tuple(round(float(coord), 4) for coord in coordinates.split(","))
        existing_pin = pins_collection.find_one({"coordinates": coords, "type": pin_type})

        if existing_pin and (existing_pin["email"] == email
                             or email in existing_pin.get("reported_by", {})):
            return response, 200

        try:
            reporter_ip = ip
            if existing_pin:
                owner_email = existing_pin.get("email")
                owner_ip = None
                if owner_email:
                    owner_user = users_collection.find_one({"email": owner_email},
                                                           {"ip_address": 1})
                    owner_ip = owner_user.get("ip_address") if owner_user else None

                if reporter_ip and owner_ip and reporter_ip == owner_ip:
                    return response, 200

                reported_by_emails = list(existing_pin.get("reported_by", {}).keys())
                if reported_by_emails:
                    cursor = users_collection.find({"email": {"$in": reported_by_emails}},
                                                   {"ip_address": 1})
                    reported_ips = {u.get("ip_address") for u in cursor if u.get("ip_address")}
                    if reporter_ip in reported_ips:
                        return response, 200
        except Exception as e:
            print(f"Specific error occurred during IP duplicate check: {e}")

        recent_incidents = get_recent_incidents(user)
        for incident in recent_incidents:
            if incident["time"] < datetime.utcnow() - timedelta(
                    hours=settings.RECENT_INCIDENT_CLEANUP):
                recent_incidents.remove(incident)

        recent_incidents.append({"coordinates": coords, "time": datetime.utcnow()})

        if len(recent_incidents) >= 2:
            if calculate_block_distance_count(settings.TRIGGER_DISTANCE, recent_incidents):
                update_trust_score(
                    users_collection=users_collection,
                    receiving_email=email,
                    value=-0.5
                )
                log_action(logs_collection, email, "suspicious_activity")

                if (calculate_block_distance_count(settings.TRIGGER_DISTANCE * 2,
                                                   recent_incidents) or
                        calculate_block_distance_count(settings.TRIGGER_DISTANCE,
                                                       recent_incidents) >= 2):
                    update_trust_score(
                        users_collection=users_collection,
                        receiving_email=email,
                        value=-0.5
                    )
                    log_action(logs_collection, email, "strongly_suspicious_activity")
                    return response, 200

                if calculate_block_distance_count(settings.BLOCK_DISTANCE, recent_incidents) >= 2:
                    blocked_users_collection.update_one(
                        {"email": email}, {"$set": {"isBlocked": True}})
                    log_action(logs_collection, email, "blocked_unreasonable_distance")
                    return response, 200
                recent_incidents = [{"coordinates": coords, "time": datetime.utcnow()}]

        users_collection.update_one({"email": email},
                                    {"$set": {"recent_incidents": recent_incidents}})

        if existing_pin:
            update_data = {
                "$inc": {"reports": retrieve_trust_score(users_collection, email)},
                "$set": {
                    f"reported_by.{email}": True,
                    "update_date": datetime.utcnow()
                }
            }
            if existing_pin["reports"] == settings.MIN_REPORTS - 1:
                update_data["$set"]["creation_date"] = datetime.utcnow()

            pins_collection.find_one_and_update(
                {"coordinates": coords, "type": pin_type, f"reported_by.{email}":
                    {"$exists": False}},
                update_data
            )
            users_collection.update_one({"email": email},
                                        {"$inc": {"karma": 2}})
            users_collection.update_one({"email": existing_pin["email"]},
                                        {"$inc": {"karma": 5}})
            update_trust_score(
                users_collection=users_collection,
                receiving_email=existing_pin["email"],
                value=0.15,
                reporter_email=email
            )
        else:
            pins_collection.insert_one({
                "creation_date": datetime.utcnow(),
                "coordinates": coords,
                "type": pin_type,
                "update_date": datetime.utcnow(),
                "email": email,
                "reports": retrieve_trust_score(users_collection, email),
                "reported_by": {email: True}
            })
            users_collection.update_one({"email": email},
                                        {"$inc": {"karma": 8}})

        response = "true" if cookie_status is True else cookie_status

    except Exception as e:
        print(f"Specific error occurred: {e}")

    return response, 200


@reporting_bp.route('/pindelete', methods=['POST'])
@limiter.limit(settings.PIN_RATE_LIMIT)
def pindelete():
    """
        Deletes a pin from the database with the provided email, coordinates, and pin type.

        Returns:
            str: "true" if the pin is deleted successfully,
            "false" if validation fails or user is blocked
            or "error" if cookie validation fails.
    """
    response = "false"

    try:
        email, cookie, _, coordinates, pin_type, ip = clean(
            email=request.json["email"],
            cookie=request.json["cookie"],
            coordinates=request.json["coordinates"],
            pin_type=request.json["pin_type"],
            ip_address=request.access_route[0]
        )

        if not email or not coordinates or not pin_type or not ip:
            return response, 200
        if not cookie:
            return "error", 200

        user, cookie_status = user_status(users_collection, blocked_users_collection,
                                          settings, email, cookie)
        if user and user["registered"] and cookie_status and cookie_status != "error":
            coords = tuple(round(float(coord), 4) for coord in coordinates.split(","))
            pin_item = pins_collection.find_one({"coordinates": coords, "type": pin_type})

            if (pin_item and pin_item["email"] != email
                    and email not in pin_item.get("reported_by", {})):
                try:
                    reporter_ip = ip
                    owner_user = users_collection.find_one({"email": pin_item.get("email")},
                                                           {"ip_address": 1})
                    owner_ip = owner_user.get("ip_address") if owner_user else None
                    if reporter_ip and owner_ip and reporter_ip == owner_ip:
                        return response, 200

                    reported_by_emails = list(pin_item.get("reported_by", {}).keys())
                    if reported_by_emails:
                        cursor = users_collection.find({"email": {"$in": reported_by_emails}},
                                                       {"ip_address": 1})
                        reported_ips = {u.get("ip_address") for u in cursor if u.get("ip_address")}
                        if reporter_ip in reported_ips:
                            return response, 200
                except Exception as e:
                    print(f"Specific error occurred during IP duplicate check: {e}")
                pin_item = pins_collection.find_one_and_update(
                    {"coordinates": coords, "type": pin_type},
                    {
                        "$inc": {"reports": -retrieve_trust_score(users_collection, email)},
                        "$set": {f"reported_by.{email}": True}
                    },
                    return_document=pymongo.ReturnDocument.AFTER
                )
                users_collection.update_one({"email": pin_item["email"]},
                                            {"$inc": {"karma": -1}})
                users_collection.update_one({"email": email}, {"$inc": {"karma": 2}})
                pin_age = datetime.utcnow() - pin_item["creation_date"]
                value = -0.20 * (0.5 ** (pin_age.total_seconds() / 5400))
                update_trust_score(
                    users_collection=users_collection,
                    receiving_email=pin_item["email"],
                    value=value,
                    reporter_email=email
                )
                response = "true" if cookie_status is True else cookie_status
    except Exception as e:
        print(f"Specific error occurred: {e}")
    return response, 200
