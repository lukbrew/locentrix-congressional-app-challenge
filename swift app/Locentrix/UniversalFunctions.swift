import SwiftUI
import CoreLocation
import Foundation
import UserNotifications
import AVFoundation


struct CodableCoordinate: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    static func == (lhs: CodableCoordinate, rhs: CodableCoordinate) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}


struct UserIncident: Codable, Identifiable {
    let id: UUID
    let type: String
    let coordinate: CodableCoordinate
    let timestamp: Date
    var receiveNotifications: Bool
    
    init(id: UUID = UUID(), type: String, coordinate: CodableCoordinate, timestamp: Date, receiveNotifications: Bool) {
        self.id = id
        self.type = type
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.receiveNotifications = receiveNotifications
    }
}


struct CustomAlertView: View {
    var message: String
    var color: Color
    @Binding var showAlert: Bool

    var body: some View {
        if showAlert {
            VStack {
                Text(message)
                    .padding()
                    .background(color)
                    .cornerRadius(8)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .padding()
                Button("OK") {
                    showAlert = false
                }
                .buttonStyle(DefaultButtonStyle())
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.8))
            .edgesIgnoringSafeArea(.all)
        }
    }
}


func loadIncidents(from key: String) -> [UserIncident] {
    guard let savedData = UserDefaults.standard.data(forKey: key),
          let decodedIncidents = try? JSONDecoder().decode([UserIncident].self, from: savedData) else {
        return []
    }

    let validIncidents = decodedIncidents.filter { Date().timeIntervalSince($0.timestamp) < 86400 }

    if let encoded = try? JSONEncoder().encode(validIncidents) {
        UserDefaults.standard.set(encoded, forKey: key)
    }

    return validIncidents
}


func saveIncident(type: String, coordinate: CLLocationCoordinate2D, receiveNotifications: Bool, to key: String) {
    var incidents = loadIncidents(from: key)
    let newIncident = UserIncident(
        type: type,
        coordinate: CodableCoordinate(coordinate: coordinate),
        timestamp: Date(),
        receiveNotifications: receiveNotifications
    )

    incidents.append(newIncident)

    if let encodedData = try? JSONEncoder().encode(incidents) {
        UserDefaults.standard.set(encodedData, forKey: key)
    }
}


func saveIncidents(_ incidents: [UserIncident], to key: String) {
    if let encodedData = try? JSONEncoder().encode(incidents) {
        UserDefaults.standard.set(encodedData, forKey: key)
    }
}


func getIncidentColor(for type: String) -> Color {
    switch type {
    case "Construction": return .orange
    case "Traffic": return .white
    case "Crash": return .yellow
    case "Police": return .blue
    case "Damage": return .red
    case "Debris": return .black
    default: return .gray
    }
}

struct NotificationHelper {
    static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    static func sendNotification(for incident: UserIncident, title: String, body: String, lastNotificationTimes: inout [UUID: Date], cooldown: TimeInterval = 600) {
        let now = Date()
        
        if let lastTime = lastNotificationTimes[incident.id], now.timeIntervalSince(lastTime) < cooldown {
            print("Skipping duplicate notification for \(incident.id) due to cooldown.")
            return
        }

        lastNotificationTimes[incident.id] = now


        let pushOutsideAppEnabled: Bool
        if UserDefaults.standard.object(forKey: "enablePushOutsideApp") == nil {
            pushOutsideAppEnabled = true
        } else {
            pushOutsideAppEnabled = UserDefaults.standard.bool(forKey: "enablePushOutsideApp")
        }

        if pushOutsideAppEnabled {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        } else {
            print("System push notifications are disabled by user preference; skipping scheduling a UNNotificationRequest.")
        }
        
        InAppNotificationManager.shared.showInAppNotification(for: incident, title: title, body: body)
    }
    
    static func loadLastNotificationTimes(from key: String) -> [UUID: Date] {
        if let savedData = UserDefaults.standard.data(forKey: key),
           let decodedTimes = try? JSONDecoder().decode([UUID: Date].self, from: savedData) {
            return decodedTimes
        }
        return [:]
    }
    
    static func saveLastNotificationTimes(_ times: [UUID: Date], to key: String) {
        if let encodedData = try? JSONEncoder().encode(times) {
            UserDefaults.standard.set(encodedData, forKey: key)
        }
    }
}

class TTSAnnouncementManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = TTSAnnouncementManager()
    
    // Constants
    private static let metersToFeet: Double = 3.28084
    private static let announcementCooldownSeconds: TimeInterval = 600
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var announcementQueue: [String] = []
    private var isProcessingAnnouncement: Bool = false
    private var lastAnnouncedIncidents: Set<UUID> = []
    
    private override init() {
        super.init()
        speechSynthesizer.delegate = self
    }
    
    func announceIncident(_ incident: UserIncident, distance: CLLocationDistance) {
        // Check if TTS is enabled
        guard UserDefaults.standard.bool(forKey: "enableTTSAnnouncements") else {
            return
        }
        
        // Check if already announced recently
        guard !lastAnnouncedIncidents.contains(incident.id) else {
            return
        }
        
        // Mark as announced
        lastAnnouncedIncidents.insert(incident.id)
        
        // Format distance (convert meters to feet)
        let distanceInFeet = Int(distance * Self.metersToFeet)
        let announcement = "A \(incident.type) incident is ahead in approximately \(distanceInFeet) feet"
        
        queueAnnouncement(announcement)
        
        // Clear the announcement flag after cooldown
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.announcementCooldownSeconds) { [weak self] in
            self?.lastAnnouncedIncidents.remove(incident.id)
        }
    }
    
    private func queueAnnouncement(_ text: String) {
        if !speechSynthesizer.isSpeaking && !isProcessingAnnouncement {
            speak(text)
        } else {
            announcementQueue.append(text)
        }
    }
    
    private func speak(_ text: String) {
        isProcessingAnnouncement = true
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynthesizer.speak(utterance)
    }
    
    private func processNextAnnouncement() {
        guard !announcementQueue.isEmpty, !speechSynthesizer.isSpeaking else {
            isProcessingAnnouncement = false
            return
        }
        let nextAnnouncement = announcementQueue.removeFirst()
        speak(nextAnnouncement)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        processNextAnnouncement()
    }
    
    func clearAnnouncements() {
        announcementQueue.removeAll()
        speechSynthesizer.stopSpeaking(at: .immediate)
        isProcessingAnnouncement = false
    }
}
