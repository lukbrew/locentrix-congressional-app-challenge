import SwiftUI
import MapKit
import CoreLocation
import UserNotifications
import Foundation

struct Privatemap: View {
    @ObservedObject var locationManager = PrivateLocationManager.shared
    @ObservedObject var directionsManager = DirectionsManager.shared
    @State private var position: MapCameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
    @State private var isFollowingUser = true
    @State private var incidents: [UserIncident] = []
    @State private var showDirectionsSearch = false
    @State private var showDirectionsError = false
    @State private var directionsErrorMessage = ""

    var body: some View {
        VStack {
            PrivateHeaderView()
            HStack {
                Button("Follow Me") {
                    if locationManager.location != nil {
                        isFollowingUser = true
                        position = .userLocation(followsHeading: true, fallback: .automatic)
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)


                Button(action: {
                    showDirectionsSearch = true
                }) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .accessibilityLabel("Directions")
                }

                Spacer()
                
                NavigationLink(destination: DeletePrivateIncident()) {
                    Text("Delete")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                NavigationLink(destination: ReportPrivateIncident(onIncidentReported: {
                    incidents = loadIncidents(from: "storedPrivateIncidents")
                })) {
                    Text("Add")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()

            ZStack {
                Group {
                    if let status = locationManager.authorizationStatus, (status == .authorizedWhenInUse || status == .authorizedAlways) {
                        Map(position: $position) {
                            if locationManager.location != nil {
                                UserAnnotation()
                            }

                            ForEach(incidents) { incident in
                                Annotation(incident.type, coordinate: incident.coordinate.coordinate) {
                                    ZStack {
                                        Circle()
                                            .fill(getIncidentColor(for: incident.type))
                                            .frame(width: 12, height: 12)
                                        Text(incident.type.prefix(1))
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            
                            // Prefer showing the trimmed remaining polyline while navigating.
                            if directionsManager.isNavigating {
                                if let remaining = directionsManager.remainingRoutePolyline {
                                    MapPolyline(remaining)
                                        .stroke(Color.blue, lineWidth: 6)
                                } else if let route = directionsManager.currentRoute {
                                    // Fallback to full route polyline until trimming is computed
                                    MapPolyline(route.polyline)
                                        .stroke(Color.blue, lineWidth: 6)
                                }

                                // Show the completed portion behind the user as a faded polyline
                                if let completed = directionsManager.completedRoutePolyline {
                                    MapPolyline(completed)
                                        .stroke(Color.blue.opacity(0.35), lineWidth: 6)
                                }
                            } else {
                                // Not actively navigating: show full route if present
                                if let route = directionsManager.currentRoute {
                                    MapPolyline(route.polyline)
                                        .stroke(Color.blue, lineWidth: 6)
                                }
                            }
                        }
                        .onAppear {
                            incidents = loadIncidents(from: "storedPrivateIncidents")
                        }
                        .simultaneousGesture(
                            DragGesture().onChanged { _ in
                                isFollowingUser = false
                            }
                        )
                        .onChange(of: locationManager.location) { _, newLocation in
                            if let location = newLocation {
                                directionsManager.updateLocation(location)
                                // Update the trimmed polylines for a smooth 'route behind me' effect
                                directionsManager.updateRemainingPolyline(using: location)
                                directionsManager.checkForNearbyIncidents(userLocation: location, incidents: incidents)
                            }
                            if isFollowingUser && !directionsManager.isNavigating {
                                position = .userLocation(followsHeading: true, fallback: .automatic)
                            }
                        }
                    } else {
                        Text("Location access is required to view the map.")
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                
                DirectionsOverlayView(onEndRoute: {
                    directionsManager.stopNavigation()
                })
            }
            .sheet(isPresented: $showDirectionsSearch) {
                DirectionsSearchView(
                    userLocation: locationManager.location?.coordinate,
                    onDestinationSelected: { destination, _ in
                        startNavigation(to: destination)
                    }
                )
            }
            .alert("Directions Error", isPresented: $showDirectionsError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(directionsErrorMessage)
            }
        }
    }
    
    private func startNavigation(to destination: CLLocationCoordinate2D) {
        guard let userLocation = locationManager.location?.coordinate else {
            directionsErrorMessage = "Current location not available. Please ensure location services are enabled."
            showDirectionsError = true
            return
        }
        
        directionsManager.requestDirections(from: userLocation, to: destination, avoiding: incidents) { result in
            switch result {
            case .success(_):
                directionsManager.startNavigation()
                isFollowingUser = true
            case .failure(let error):
                directionsErrorMessage = "Failed to get directions: \(error.localizedDescription).\nPlease check your internet connection and try again, or verify that the destination is reachable."
                showDirectionsError = true
            }
        }
    }
}

struct Publicmap: View {
    @ObservedObject var locationManager = PublicLocationManager.shared
    @ObservedObject var directionsManager = DirectionsManager.shared
    @State private var position: MapCameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
    @State private var isFollowingUser = true
    @State private var incidents: [UserIncident] = []
    @State private var downloadedIncidents: [UserIncident] = []
    @State private var email: String = ""
    @State private var isSignedIn = false
    @State private var enableNotifications = false
    @State private var lastNotificationTimes: [UUID: Date] = [:]
    @State private var showDirectionsSearch = false
    @State private var showDirectionsError = false
    @State private var directionsErrorMessage = ""

    @State private var updateTimer: Timer?
    @State private var proximityCheckTimer: Timer?

    @State private var isDataFetchingEnabled: Bool = UserDefaults.standard.bool(forKey: "isDataFetchingEnabled") {
        didSet {
            UserDefaults.standard.set(isDataFetchingEnabled, forKey: "isDataFetchingEnabled")
            if isDataFetchingEnabled {
                loadInitialPins()
                startUpdatingPins()
            } else {
                downloadedIncidents.removeAll()
                stopUpdatingPins()
            }
        }
    }

    var body: some View {
        VStack {
            if isSignedIn {
                PublicHeaderView()
                mapView
            } else {
                AuthenticationView(isSignedIn: $isSignedIn)
            }
        }
        .onAppear {
            if let savedEmail = UserDefaults.standard.string(forKey: "userEmail") {
                email = savedEmail
                isSignedIn = true
            }
            NotificationHelper.requestNotificationPermission()
            loadLastNotificationTimes()
            if isDataFetchingEnabled {
                startUpdatingPins()
            }
        }
    }

    var mapView: some View {
        VStack {
            HStack {
                Button("Follow Me") {
                    if locationManager.location != nil {
                        isFollowingUser = true
                        position = .userLocation(followsHeading: true, fallback: .automatic)
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)

                Button(action: {
                    showDirectionsSearch = true
                }) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .accessibilityLabel("Directions")
                }
                
                Spacer()

                Menu {
                    Toggle("Enable Notifications", isOn: Binding(
                        get: { UserDefaults.standard.bool(forKey: "enableNotifications") },
                        set: { newValue in
                            UserDefaults.standard.set(newValue, forKey: "enableNotifications")
                            enableNotifications = newValue
                        }
                    ))
                    Toggle("Enable Data Fetching", isOn: Binding(
                        get: { UserDefaults.standard.bool(forKey: "isDataFetchingEnabled") },
                        set: { newValue in
                            UserDefaults.standard.set(newValue, forKey: "isDataFetchingEnabled")
                            isDataFetchingEnabled = newValue
                            if newValue {
                                startUpdatingPins()
                            } else {
                                stopUpdatingPins()
                            }
                        }
                    ))
                } label: {
                    Label("", systemImage: "gearshape.fill")
                        .labelStyle(.iconOnly)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }


                NavigationLink(destination: ReportPrivateIncident(onIncidentReported: {
                    incidents = loadIncidents(from: "storedPublicIncidents")
                })) {
                    Text("Add")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()

            ZStack {
                Group {
                    if let status = locationManager.authorizationStatus, (status == .authorizedWhenInUse || status == .authorizedAlways) {
                        Map(position: $position) {
                            if locationManager.location != nil {
                                UserAnnotation()
                            }

                            ForEach(incidents) { incident in
                                Annotation(incident.type, coordinate: incident.coordinate.coordinate) {
                                    ZStack {
                                        Circle()
                                            .fill(getIncidentColor(for: incident.type))
                                            .frame(width: 12, height: 12)
                                        Text(incident.type.prefix(1))
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                }
                            }

                            ForEach(downloadedIncidents) { incident in
                                Annotation(incident.type, coordinate: incident.coordinate.coordinate) {
                                    ZStack {
                                        Circle()
                                            .fill(getIncidentColor(for: incident.type))
                                            .frame(width: 12, height: 12)
                                        Text(incident.type.prefix(1))
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            
                            // Prefer showing the trimmed remaining polyline while navigating.
                            if directionsManager.isNavigating {
                                if let remaining = directionsManager.remainingRoutePolyline {
                                    MapPolyline(remaining)
                                        .stroke(Color.blue, lineWidth: 6)
                                } else if let route = directionsManager.currentRoute {
                                    // Fallback to full route polyline until trimming is computed
                                    MapPolyline(route.polyline)
                                        .stroke(Color.blue, lineWidth: 6)
                                }

                                // Show the completed portion behind the user as a faded polyline
                                if let completed = directionsManager.completedRoutePolyline {
                                    MapPolyline(completed)
                                        .stroke(Color.blue.opacity(0.35), lineWidth: 6)
                                }
                            } else {
                                // Not actively navigating: show full route if present
                                if let route = directionsManager.currentRoute {
                                    MapPolyline(route.polyline)
                                        .stroke(Color.blue, lineWidth: 6)
                                }
                            }
                        }
                        .onAppear {
                            if UserDefaults.standard.object(forKey: "enableNotifications") == nil {
                                UserDefaults.standard.set(true, forKey: "enableNotifications")
                            }
                            enableNotifications = UserDefaults.standard.bool(forKey: "enableNotifications")

                            if UserDefaults.standard.object(forKey: "isDataFetchingEnabled") == nil {
                                UserDefaults.standard.set(true, forKey: "isDataFetchingEnabled")
                            }
                            isDataFetchingEnabled = UserDefaults.standard.bool(forKey: "isDataFetchingEnabled")

                            if isDataFetchingEnabled {
                                loadInitialPins()
                                startUpdatingPins()
                            }
                            if enableNotifications {
                                startProximityChecks()
                            }
                        }
                        .onDisappear {
                            stopProximityChecks()
                        }
                        .highPriorityGesture(
                            DragGesture().onChanged { _ in
                                if isFollowingUser {
                                    isFollowingUser = false
                                }
                            }
                        )
                        .onChange(of: locationManager.location) { _, newLocation in
                            if let location = newLocation {
                                directionsManager.updateLocation(location)
                                // Update the trimmed polylines so the completed portion fades behind the user
                                directionsManager.updateRemainingPolyline(using: location)
                                let allIncidents = incidents + downloadedIncidents
                                directionsManager.checkForNearbyIncidents(userLocation: location, incidents: allIncidents)
                            }
                            if isFollowingUser && !directionsManager.isNavigating {
                                position = .userLocation(followsHeading: true, fallback: .automatic)
                            }
                        }
                    } else {
                        Text("Location access is required to view the map.")
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                
                DirectionsOverlayView(onEndRoute: {
                    directionsManager.stopNavigation()
                })
            }
            .sheet(isPresented: $showDirectionsSearch) {
                DirectionsSearchView(
                    userLocation: locationManager.location?.coordinate,
                    onDestinationSelected: { destination, _ in
                        startNavigation(to: destination)
                    }
                )
            }
            .alert("Directions Error", isPresented: $showDirectionsError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(directionsErrorMessage)
            }
        }
    }

    func startUpdatingPins() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            updatePins()
        }
    }

    func stopUpdatingPins() {
        updateTimer?.invalidate()
        updateTimer = nil
        print("Data fetching disabled.")
    }

    func startProximityChecks() {
        proximityCheckTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            checkProximityAndNotify()
        }
    }

    func stopProximityChecks() {
        proximityCheckTimer?.invalidate()
        proximityCheckTimer = nil
        print("Proximity checks disabled.")
    }

    func loadInitialPins() {
        guard let cookie = UserDefaults.standard.string(forKey: "userCookie") else { return }
        let urlString = "https://locentrix.legendarycoding.com/api/pin/retrieval/pinrequest"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "cookie": cookie]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let response = String(data: data, encoding: .utf8) {
                downloadedIncidents = handleResponse(response, incidents: downloadedIncidents)
            }
        }.resume()
    }

    func updatePins() {
        guard let cookie = UserDefaults.standard.string(forKey: "userCookie") else { return }

        let oldUrlString = "https://locentrix.legendarycoding.com/api/retrieval/pinold"
        guard let oldUrl = URL(string: oldUrlString) else { return }

        var oldRequest = URLRequest(url: oldUrl)
        oldRequest.httpMethod = "POST"
        oldRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "cookie": cookie]
        oldRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: oldRequest) { data, _, _ in
            if let data = data, let response = String(data: data, encoding: .utf8) {
                downloadedIncidents = handleResponse(response, incidents: downloadedIncidents, remove: true)
            }
        }.resume()

        let newUrlString = "https://locentrix.legendarycoding.com/api/retrieval/pinnew"
        guard let newUrl = URL(string: newUrlString) else { return }

        var newRequest = URLRequest(url: newUrl)
        newRequest.httpMethod = "POST"
        newRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        newRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: newRequest) { data, _, _ in
            if let data = data, let response = String(data: data, encoding: .utf8) {
                downloadedIncidents = handleResponse(response, incidents: downloadedIncidents)
            }
        }.resume()
    }

    func handleResponse(_ response: String, incidents: [UserIncident], remove: Bool = false) -> [UserIncident] {
        var updatedIncidents = incidents
        let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedResponse == "error" {
            signOutUser()
        } else if let newCookie = Int(trimmedResponse) {
            UserDefaults.standard.set(newCookie, forKey: "userCookie")
        } else if trimmedResponse != "false" {
            let pins = parsePinData(trimmedResponse)
            if remove {
                updatedIncidents.removeAll { pin in
                    pins.contains { $0.coordinate == pin.coordinate }
                }
            } else {
                updatedIncidents.append(contentsOf: pins)
            }
        }
        return updatedIncidents
    }

    func parsePinData(_ pinString: String) -> [UserIncident] {
        let lines = pinString.split(separator: "\n")
        var parsedIncidents: [UserIncident] = []

        for line in lines {
            let components = line.dropFirst().split(separator: ",", maxSplits: 1)
            if components.count == 2 {
                let type = String(components[0]).trimmingCharacters(in: .whitespaces)

                let coordinateString = components[1]
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")

                let coordinateParts = coordinateString.split(separator: ",")
                if coordinateParts.count == 2,
                   let latitude = Double(coordinateParts[0].trimmingCharacters(in: .whitespaces)),
                   let longitude = Double(coordinateParts[1].trimmingCharacters(in: .whitespaces)) {

                    let newIncident = UserIncident(
                        type: type,
                        coordinate: CodableCoordinate(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)),
                        timestamp: Date(),
                        receiveNotifications: false
                    )

                    parsedIncidents.append(newIncident)
                }
            }
        }

        return parsedIncidents
    }

    func checkProximityAndNotify() {
        guard enableNotifications, let userLocation = locationManager.location else { return }

        for incident in downloadedIncidents {
            let incidentLocation = CLLocation(latitude: incident.coordinate.coordinate.latitude, longitude: incident.coordinate.coordinate.longitude)
            let distance = userLocation.distance(from: incidentLocation)

            if distance < 1000 {
                NotificationHelper.sendNotification(
                    for: incident,
                    title: "Nearby Road Incident",
                    body: "There is a \(incident.type) incident nearby.",
                    lastNotificationTimes: &lastNotificationTimes
                )
                NotificationHelper.saveLastNotificationTimes(lastNotificationTimes, to: "lastNotificationTimes")
                
                // Announce via TTS if enabled and not navigating
                if !directionsManager.isNavigating {
                    TTSAnnouncementManager.shared.announceIncident(incident, distance: distance)
                }
                break
            }
        }
    }

    private func loadLastNotificationTimes() {
        lastNotificationTimes = NotificationHelper.loadLastNotificationTimes(from: "lastNotificationTimes")
    }

    func signOutUser() {
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "userCookie")
        isSignedIn = false
    }
    
    private func startNavigation(to destination: CLLocationCoordinate2D) {
        guard let userLocation = locationManager.location?.coordinate else {
            directionsErrorMessage = "Current location not available. Please ensure location services are enabled."
            showDirectionsError = true
            return
        }
        
        // Combine both local and downloaded incidents for avoidance
        let allIncidents = incidents + downloadedIncidents
        directionsManager.requestDirections(from: userLocation, to: destination, avoiding: allIncidents) { result in
            switch result {
            case .success(_):
                directionsManager.startNavigation()
                isFollowingUser = true
            case .failure(let error):
                directionsErrorMessage = "Failed to get directions: \(error.localizedDescription).\nPlease check your internet connection and try again, or verify that the destination is reachable."
                showDirectionsError = true
            }
        }
    }
}
