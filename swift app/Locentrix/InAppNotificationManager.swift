import SwiftUI
import CoreLocation

class InAppNotificationManager: ObservableObject {
    static let shared = InAppNotificationManager()
    
    @Published var showNotification: Bool = false
    @Published var currentIncident: UserIncident?
    @Published var notificationTitle: String = ""
    @Published var notificationBody: String = ""
    
    private var dismissTimer: Timer?
    
    private init() {}
    
    func showInAppNotification(for incident: UserIncident, title: String, body: String) {
        DispatchQueue.main.async {
            self.currentIncident = incident
            self.notificationTitle = title
            self.notificationBody = body
            self.showNotification = true
            
            self.dismissTimer?.invalidate()
            self.dismissTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { _ in
                self.dismissNotification()
            }
        }
    }
    
    func dismissNotification() {
        DispatchQueue.main.async {
            self.showNotification = false
            self.currentIncident = nil
            self.dismissTimer?.invalidate()
            self.dismissTimer = nil
        }
    }
    
    func handleAgree() {
        guard let incident = currentIncident else { return }
        
        let incidents = loadIncidents(from: "storedPrivateIncidents")
        if !incidents.contains(where: { areCoordinatesEqual($0.coordinate, incident.coordinate) }) {
            saveIncident(
                type: incident.type,
                coordinate: incident.coordinate.coordinate,
                receiveNotifications: false,
                to: "storedPrivateIncidents"
            )
        }
        
        if let email = UserDefaults.standard.string(forKey: "userEmail") {
            guard let cookie = UserDefaults.standard.string(forKey: "userCookie") else { return }
            let urlString = "https://locentrix.legendarycoding.com/api/pin/reporting/pin"
            
            guard let url = URL(string: urlString) else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "email": email.lowercased(),
                "coordinate": "\(incident.coordinate.latitude),\(incident.coordinate.longitude)",
                "type": incident.type,
                "cookie": cookie
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error agreeing to incident: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    print("Server returned status code: \(httpResponse.statusCode)")
                    return
                }
                
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    let trimmed = responseString.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Handle responses similar to Maps/ReportPrivateIncident
                    if trimmed == "error" {
                        DispatchQueue.main.async {
                            UserDefaults.standard.removeObject(forKey: "userEmail")
                            UserDefaults.standard.removeObject(forKey: "userCookie")
                            // Clear notification state
                            self.dismissNotification()
                        }
                        print("Agree response: session error")
                    } else if trimmed == "true" {
                        print("Agree response: true")
                    } else if trimmed == "false" {
                        print("Agree response: false")
                    } else if !trimmed.isEmpty {
                        if let newCookieInt = Int(trimmed) {
                            UserDefaults.standard.set(newCookieInt, forKey: "userCookie")
                        } else {
                            UserDefaults.standard.set(trimmed, forKey: "userCookie")
                        }
                        print("Agree response: new cookie saved")
                    } else {
                        print("Agree response: unexpected")
                    }
                }
            }.resume()
        }
        
        dismissNotification()
    }
    
    func handleDisagree() {
        guard let incident = currentIncident else { return }
        
        var incidents = loadIncidents(from: "storedPrivateIncidents")
        if let index = incidents.firstIndex(where: {
            $0.id == incident.id || areCoordinatesEqual($0.coordinate, incident.coordinate)
        }) {
            incidents.remove(at: index)
            saveIncidents(incidents, to: "storedPrivateIncidents")
        }
        
        if let email = UserDefaults.standard.string(forKey: "userEmail") {
            guard let cookie = UserDefaults.standard.string(forKey: "userCookie") else { return }
            let urlString = "https://locentrix.legendarycoding.com/api/pin/reporting/pindelete"
            
            guard let url = URL(string: urlString) else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "email": email.lowercased(),
                "coordinate": "\(incident.coordinate.latitude),\(incident.coordinate.longitude)",
                "type": incident.type,
                "cookie": cookie
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error disagreeing with incident: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    print("Server returned status code: \(httpResponse.statusCode)")
                    return
                }
                
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    let trimmed = responseString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed == "error" {
                        DispatchQueue.main.async {
                            UserDefaults.standard.removeObject(forKey: "userEmail")
                            UserDefaults.standard.removeObject(forKey: "userCookie")
                            self.dismissNotification()
                        }
                        print("Disagree response: session error")
                    } else if trimmed == "true" {
                        print("Disagree response: true")
                    } else if trimmed == "false" {
                        print("Disagree response: false")
                    } else if !trimmed.isEmpty {
                        if let newCookieInt = Int(trimmed) {
                            UserDefaults.standard.set(newCookieInt, forKey: "userCookie")
                        } else {
                            UserDefaults.standard.set(trimmed, forKey: "userCookie")
                        }
                        print("Disagree response: new cookie saved")
                    } else {
                        print("Disagree response: unexpected")
                    }
                }
            }.resume()
        }
        
        dismissNotification()
    }
    

    private func areCoordinatesEqual(_ coord1: CodableCoordinate, _ coord2: CodableCoordinate, tolerance: Double = 0.0006) -> Bool {
        return abs(coord1.latitude - coord2.latitude) < tolerance &&
               abs(coord1.longitude - coord2.longitude) < tolerance
    }
}
