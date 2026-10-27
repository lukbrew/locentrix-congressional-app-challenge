import Foundation

struct IncidentTypes {
    static let all = ["Construction", "Traffic", "Crash", "Debris", "Damage", "Police", "Other"]
    
    static let synonyms: [String: String] = [
        "accident": "Crash",
        "collision": "Crash",
        "wreck": "Crash",
        "road work": "Construction",
        "roadwork": "Construction",
        "construction zone": "Construction",
        "workers": "Construction",
        "jam": "Traffic",
        "congestion": "Traffic",
        "cars": "Traffic",
        "vehicles": "Traffic",
        "cop": "Police",
        "officer": "Police",
        "trash": "Debris",
        "pothole": "Damage"
    ]
}
