import Foundation
import CoreLocation
import SwiftUI
import MapKit
import UserNotifications


class PublicLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = PublicLocationManager()

    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus?

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
    }
}

class PrivateLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
    static let shared = PrivateLocationManager()

    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus?

    private let storedIncidentsKey = "storedPrivateIncidents"
    private let lastNotificationTimesKey = "lastPrivateNotificationTimes"
    private let notificationPermissionRequestedKey = "privateNotificationPermissionRequested"

    private var checkProximityTimer: Timer?
    private let notificationCenter = UNUserNotificationCenter.current()
    private var lastNotificationTimes: [UUID: Date] = [:]
    private var notificationInProgress: [UUID: Bool] = [:]
    private var lastProximityCheckTime: Date?
    private var appStartTime: Date

    private override init() {
        self.appStartTime = UserDefaults.standard.object(forKey: "appStartTime") as? Date ?? Date()
        super.init()

        UNUserNotificationCenter.current().delegate = self
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        requestNotificationPermission()

        loadLastNotificationTimes()

        if checkProximityTimer == nil {
            checkProximityTimer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(checkProximityToMarkers), userInfo: nil, repeats: true)
            print("Proximity timer started (singleton instance)")
        } else {
            print("Proximity timer already running, skipping initialization")
        }
    }

    private func requestNotificationPermission() {
        let permissionRequested = UserDefaults.standard.bool(forKey: notificationPermissionRequestedKey)
        if !permissionRequested {
            NotificationHelper.requestNotificationPermission()
            UserDefaults.standard.set(true, forKey: notificationPermissionRequestedKey)
        }
    }

    @objc private func checkProximityToMarkers() {
        let now = Date()

        if let lastCheck = lastProximityCheckTime, now.timeIntervalSince(lastCheck) < 3 {
            print("Skipping proximity check: too soon since last check")
            return
        }

        lastProximityCheckTime = now
        print("Running proximity check at \(now)")

        guard let userLocation = location else {
            print("User location is nil")
            return
        }

        let incidents = loadIncidents(from: storedIncidentsKey).filter { $0.receiveNotifications }
        notificationInProgress.removeAll()

        for incident in incidents {
            let incidentLocation = CLLocation(latitude: incident.coordinate.latitude, longitude: incident.coordinate.longitude)
            let distance = userLocation.distance(from: incidentLocation)

            print("Distance to incident \(incident.id): \(distance) meters")

            if distance <= 45.72 {
                if notificationInProgress[incident.id] != true {
                    if shouldSendNotification(for: incident.id) {
                        sendProximityNotification(for: incident)
                        lastNotificationTimes[incident.id] = now
                        notificationInProgress[incident.id] = true
                    }
                }
            }
        }
    }

    private func shouldSendNotification(for incidentID: UUID) -> Bool {
        let now = Date()

        if let lastTime = lastNotificationTimes[incidentID] {
            let timeSinceLast = now.timeIntervalSince(lastTime)
            if timeSinceLast < 600 {
                print("Skipping notification for \(incidentID): Cooldown active (\(timeSinceLast) sec).")
                return false
            }
        }

        return true
    }

    private func sendProximityNotification(for incident: UserIncident) {
        NotificationHelper.sendNotification(
            for: incident,
            title: "Nearby Saved Road Incident!",
            body: "You are close to a \(incident.type) you reported previously.",
            lastNotificationTimes: &lastNotificationTimes
        )
        saveLastNotificationTimes()
        
        // Announce via TTS if enabled and not navigating
        if !DirectionsManager.shared.isNavigating,
           let userLocation = location {
            let incidentLocation = CLLocation(latitude: incident.coordinate.latitude, longitude: incident.coordinate.longitude)
            let distance = userLocation.distance(from: incidentLocation)
            TTSAnnouncementManager.shared.announceIncident(incident, distance: distance)
        }
    }

    private func loadLastNotificationTimes() {
        lastNotificationTimes = NotificationHelper.loadLastNotificationTimes(from: lastNotificationTimesKey)
    }

    private func saveLastNotificationTimes() {
        NotificationHelper.saveLastNotificationTimes(lastNotificationTimes, to: lastNotificationTimesKey)
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            print("Location access denied or restricted.")
        case .notDetermined:
            print("Location access not determined.")
        @unknown default:
            print("Unknown authorization status.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        location = newLocation
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.list, .banner, .sound]
    }

    deinit {
        saveLastNotificationTimes()
    }
}
