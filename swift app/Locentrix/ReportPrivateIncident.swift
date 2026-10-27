import SwiftUI
import MapKit


struct ReportPrivateIncident: View {
    @State private var selectedType = "Construction"
    @State private var receiveNotifications = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertColor = Color.red.opacity(0.2)
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var locationManager = PrivateLocationManager.shared
    var onIncidentReported: () -> Void
    
    var body: some View {
        let incidentTypes = ["Construction", "Traffic", "Crash", "Debris", "Damage", "Police", "Other"]
        
        VStack {
            ReportHeaderView()
            Form {
                Toggle("Receive Notifications", isOn: $receiveNotifications)
                    .padding()
                
                Picker("Type", selection: $selectedType) {
                    ForEach(incidentTypes, id: \.self) { type in
                        Text(type)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                
                Button("Submit") {
                    if let userLocation = locationManager.location?.coordinate {
                        saveIncident(type: selectedType, coordinate: userLocation, receiveNotifications: receiveNotifications, to:"storedPrivateIncidents")
                        sendIncidentToServer(type: selectedType, coordinate: userLocation)
                        onIncidentReported()
                    }
                }
                .buttonStyle(DefaultButtonStyle())
                .padding()
            }
            .padding()
        }
        .overlay(
            CustomAlertView(message: alertMessage, color: alertColor, showAlert: $showAlert)
        )
        .frame(maxWidth: 600)
        .padding([.bottom])
    }
    
    
    // MARK: - Send Incident to Server
    func sendIncidentToServer(type: String, coordinate: CLLocationCoordinate2D) {
        if let email = UserDefaults.standard.string(forKey: "userEmail") {
            guard let cookie = UserDefaults.standard.string(forKey: "userCookie") else { return }

            let urlString = "https://locentrix.legendarycoding.com/api/pin/reporting/pin"

            guard let url = URL(string: urlString) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "email": email,
                "coordinates": "\(coordinate.latitude),\(coordinate.longitude)",
                "pin_type": type,
                "cookie": cookie
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        alertMessage = "Please check your internet connection. If your internet is working, the server may be down for maintenance. Please try again later."
                        alertColor = Color.red.opacity(0.5)
                        showAlert = true
                    }
                    print("Error sending incident: \(error.localizedDescription)")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    DispatchQueue.main.async {
                        alertMessage = "Please check your internet connection. If your internet is working, the server may be down for maintenance. Please try again later."
                        alertColor = Color.red.opacity(0.5)
                        showAlert = true
                    }
                    print("Server response: \(httpResponse.statusCode)")
                    return
                }

                if let data = data, var responseString = String(data: data, encoding: .utf8) {
                    let trimmed = responseString.trimmingCharacters(in: .whitespacesAndNewlines)

                    DispatchQueue.main.async {
                        if trimmed == "error" {
                            UserDefaults.standard.removeObject(forKey: "userEmail")
                            UserDefaults.standard.removeObject(forKey: "userCookie")

                            alertMessage = "Your session has expired. Please reload the app and sign in again."
                            alertColor = Color.red.opacity(0.5)
                            showAlert = true

                            presentationMode.wrappedValue.dismiss()

                        } else if trimmed == "true" {
                            alertMessage = "Incident successfully reported."
                            alertColor = Color.green.opacity(0.5)
                            showAlert = true

                        } else if trimmed == "false" {
                            alertMessage = "Your incident was unable to be reported online. Please make sure you haven't already reported this incident within the last 24 hours. If this error continues, your account may have been flagged for abuse of the service."
                            alertColor = Color.red.opacity(0.5)
                            showAlert = true

                        } else if !trimmed.isEmpty {
                            if let newCookieInt = Int(trimmed) {
                                UserDefaults.standard.set(newCookieInt, forKey: "userCookie")
                            } else {
                                UserDefaults.standard.set(trimmed, forKey: "userCookie")
                            }
                            alertMessage = "Incident successfully reported."
                            alertColor = Color.green.opacity(0.5)
                            showAlert = true

                        } else {
                            alertMessage = "Unexpected server response. Please try again later."
                            alertColor = Color.red.opacity(0.5)
                            showAlert = true
                        }
                    }
                }
            }.resume()
        } else {
            print("No saved email found")
            alertMessage = "Incident successfully saved privately."
            alertColor = Color.green.opacity(0.5)
            showAlert = true
        }
    }
}
