import Foundation
import MapKit
import CoreLocation
import AVFoundation

class DirectionsManager: NSObject, ObservableObject {
    static let shared = DirectionsManager()
    
    // Incident avoidance constants
    private static let incidentAvoidanceDistance: Double = 1000 // meters
    private static let incidentPenaltyWeight: Double = 100
    private static let timePenaltyWeight: Double = 0.5
    private static let routeSamplingPoints: Int = 50 // Number of points to sample along route

    // Route recalculation constants
    private static let routeDeviationThreshold: Double = 80.0 // meters off-route before recalculating
    private static let recalculationCooldown: TimeInterval = 30.0 // minimum seconds between recalculations
    
    // Direction bias constants for recalculation
    private static let minimumSpeedForDirectionBias: Double = 0.0 // m/s (~2.2 mph); below this speed, no direction bias applied
    private static let directionBiasWeight: Double = 7.5 // max score penalty for a route going 180° against travel direction
                                                          // equivalent to ~15 extra minutes (7.5 / timePenaltyWeight=0.5)
    private static let routeInitialBearingSampleDistance: Double = 200.0 // meters to sample along route start for bearing
    
    // Unit conversion constants
    private static let metersToMiles: Double = 1609.34
    private static let metersToFeet: Double = 3.28084
    private static let metersPerSecondToMph: Double = 2.23694
    
    @Published var isNavigating: Bool = false
    @Published var isRecalculating: Bool = false
    @Published var currentRoute: MKRoute?
    @Published var remainingDistance: CLLocationDistance = 0
    @Published var estimatedTimeRemaining: TimeInterval = 0
    @Published var currentStepIndex: Int = 0
    @Published var nextInstruction: String = ""
    @Published var nextTurnDistance: CLLocationDistance = 0
    @Published var currentSpeed: Double = 0
    // Polylines exposed to the map: remaining ahead and completed behind (faded)
    @Published var remainingRoutePolyline: MKPolyline?
    @Published var completedRoutePolyline: MKPolyline?

    // Stored for route recalculation
    private var routeDestination: CLLocationCoordinate2D?
    private var currentIncidents: [UserIncident] = []
    private var lastRecalculationTime: Date?
    
    private var routeSteps: [MKRoute.Step] = []
    // Indices of steps that are considered U-turns (either from instruction text or geometric detection)
    private var uTurnStepIndices: Set<Int> = []

    // U-turn detection tuning
    private static let uTurnAngleThreshold: Double = 150.0 // degrees between incoming/outgoing bearings
    private static let uTurnAngleSampleDistance: Double = 20.0 // meters to sample near ends of a step
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var lastAnnouncedStepIndex: Int = -1
    private var lastAnnouncedIncidents: Set<UUID> = []
    private var announcementQueue: [String] = []
    private var isProcessingAnnouncement: Bool = false
    // Track whether we've already repeated the announcement for the current step when near the turn
    private var lastAnnouncedRepeatStepIndex: Int = -1

    // Distance threshold (in meters) to repeat the instruction when approaching the turn
    private static let repeatAnnounceDistanceThreshold: CLLocationDistance = 200.0
    
    private override init() {
        super.init()
        speechSynthesizer.delegate = self
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("DirectionsManager: failed to configure audio session - \(error)")
        }
    }
    
    // Note: the consolidated `requestDirections(from:to:avoiding:userHeading:completion:)` implementation
    // that computes `uTurnStepIndices` and other route metadata appears later in this file. The duplicate
    // definition was removed to avoid compile-time conflicts.
    
    // MARK: - U-turn detection helpers
    private func isUTurnInstruction(_ instr: String) -> Bool {
        let lower = instr.lowercased()
        let tokens = ["u-turn", "u turn", "uturn", "u‑turn", "make a u"]
        for t in tokens { if lower.contains(t) { return true } }
        return false
    }

    /// Geometric detection for U-turns based on the step geometry. Compares the approximate
    /// bearing at the start of the step to the bearing at the end; if they differ by at least
    /// `uTurnAngleThreshold` degrees this is likely a U-turn.
    private func isUTurnByAngle(step: MKRoute.Step) -> Bool {
        let pc = step.polyline.pointCount
        guard pc >= 2 else { return false }
        let pts = step.polyline.points()
        // Start bearing: from first point to the next
        let startA = pts[0].coordinate
        let startB = pts[min(1, pc - 1)].coordinate
        let startBearing = bearing(from: startA, to: startB)
        // End bearing: from previous to last
        let endA = pts[max(0, pc - 2)].coordinate
        let endB = pts[pc - 1].coordinate
        let endBearing = bearing(from: endA, to: endB)
        let diff = angularDifference(startBearing, endBearing)
        return diff >= Self.uTurnAngleThreshold
    }

    // MARK: - Directions request handling

    /// Request directions from source to destination, optionally avoiding specified incidents.
    /// - Parameters:
    ///   - source: The starting coordinate.
    ///   - destination: The destination coordinate.
    ///   - incidents: An array of user-reported incidents to avoid (e.g., accidents, road closures).
    ///   - userHeading: The user's current heading in degrees, if available (for directionally biased routing).
    ///   - completion: A closure called with the result of the directions request: either a successful `MKRoute`
    ///     or an `Error` describing the failure.
    func requestDirections(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, avoiding incidents: [UserIncident] = [], userHeading: Double? = nil, completion: @escaping (Result<MKRoute, Error>) -> Void) {
        // Store for potential route recalculation
        routeDestination = destination
        currentIncidents = incidents

        let sourcePlacemark = MKPlacemark(coordinate: source)
        let destinationPlacemark = MKPlacemark(coordinate: destination)
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destinationPlacemark)
        request.transportType = .automobile
        request.requestsAlternateRoutes = true // Request alternate routes for incident avoidance
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let routes = response?.routes, !routes.isEmpty, let firstRoute = routes.first else {
                completion(.failure(NSError(domain: "DirectionsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No routes found"])))
                return
            }
            
            // Select the best route based on incident avoidance and travel direction
            let bestRoute = self?.selectBestRoute(routes: routes, incidents: incidents, userHeading: userHeading) ?? firstRoute
            
            DispatchQueue.main.async {
                self?.currentRoute = bestRoute
                self?.routeSteps = bestRoute.steps

                // Compute U-turn step indices: prefer explicit instruction tokens, fallback to geometric detection
                var uTurns: Set<Int> = []
                for (i, step) in (self?.routeSteps ?? []).enumerated() {
                    if self?.isUTurnInstruction(step.instructions) == true {
                        uTurns.insert(i)
                    } else if self?.isUTurnByAngle(step: step) == true {
                        uTurns.insert(i)
                    }
                }
                self?.uTurnStepIndices = uTurns

                self?.remainingDistance = bestRoute.distance
                self?.estimatedTimeRemaining = bestRoute.expectedTravelTime
                self?.currentStepIndex = 0
                self?.updateNextInstruction()
            }
            
            completion(.success(bestRoute))
        }
    }
    
    // Route selection margin: require a candidate to be at least this much better (lower score)
    // than the current route before switching. This prevents flipping back to a slightly faster
    // route when the user is deliberately continuing in their facing direction.
    private static let rerouteAcceptanceMargin: Double = 0.5 // score units (~1 minute with current weights)

    private func selectBestRoute(routes: [MKRoute], incidents: [UserIncident], userHeading: Double? = nil) -> MKRoute {
        // Safety check - this should never happen due to guard in requestDirections
        guard let firstRoute = routes.first else {
            fatalError("selectBestRoute called with empty routes array - this should never happen")
        }

        // Helper: compute score for a single route
        func score(for route: MKRoute) -> Double {
            var score: Double = 0
            let polyline = route.polyline
            let pointCount = polyline.pointCount
            let routePoints = polyline.points()

            // Incident proximity penalties
            for incident in incidents {
                let incidentLocation = CLLocation(latitude: incident.coordinate.latitude,
                                                  longitude: incident.coordinate.longitude)
                var minDistanceToRoute = Double.infinity
                let sampleRate = max(1, pointCount / Self.routeSamplingPoints)
                for i in stride(from: 0, to: pointCount, by: sampleRate) {
                    let point = routePoints[i]
                    let pointLocation = CLLocation(latitude: point.coordinate.latitude,
                                                   longitude: point.coordinate.longitude)
                    let distance = incidentLocation.distance(from: pointLocation)
                    minDistanceToRoute = min(minDistanceToRoute, distance)
                }
                if minDistanceToRoute < Self.incidentAvoidanceDistance {
                    let penalty = (Self.incidentAvoidanceDistance - minDistanceToRoute) / Self.incidentAvoidanceDistance
                    score += penalty * Self.incidentPenaltyWeight
                }
            }

            // Time penalty (minutes * weight)
            let timePenalty = route.expectedTravelTime / 60.0
            score += timePenalty * Self.timePenaltyWeight

            // Direction bias
            if let heading = userHeading {
                let routeBearing = initialBearing(of: route)
                let angleDiff = angularDifference(heading, routeBearing)
                let normalized = (angleDiff / 180.0) * 2.0 - 1.0
                let directionScore = normalized * Self.directionBiasWeight
                score += directionScore
            }

            return score
        }

        // Score all routes
        var routeScores: [(route: MKRoute, score: Double)] = []
        for r in routes { routeScores.append((route: r, score: score(for: r))) }

        // Find the best candidate
        guard let best = routeScores.min(by: { $0.score < $1.score }) else { return firstRoute }
        let bestRoute = best.route
        let bestScore = best.score

        // If we already have a current route, compute its score and only switch if the
        // best candidate is meaningfully better by the configured margin.
        if let current = currentRoute {
            // Try to find the current route among the candidates; if it's not present, we allow switching
            if let currentEntry = routeScores.first(where: { candidate in
                // Compare by a few cheap heuristics (distance and travel time) to find a matching route
                abs(candidate.route.distance - current.distance) < 1.0 &&
                abs(candidate.route.expectedTravelTime - current.expectedTravelTime) < 5.0
            }) {
                let currentScore = currentEntry.score
                // Lower score is better. Require the new route to be at least `rerouteAcceptanceMargin`
                // lower than the current before switching to avoid flips for small gains.
                if bestRoute === current { return current }
                if currentScore - bestScore >= Self.rerouteAcceptanceMargin {
                    return bestRoute
                } else {
                    return current
                }
            }
        }

        return bestRoute
    }
    
    func startNavigation() {
        isNavigating = true
        lastAnnouncedStepIndex = -1
        lastAnnouncedIncidents.removeAll()
        announceNextInstruction()
    }
    
    func stopNavigation() {
        isNavigating = false
        isRecalculating = false
        currentRoute = nil
        routeSteps = []
        currentStepIndex = 0
        nextInstruction = ""
        nextTurnDistance = 0
        remainingDistance = 0
        estimatedTimeRemaining = 0
        lastAnnouncedStepIndex = -1
        lastAnnouncedIncidents.removeAll()
        speechSynthesizer.stopSpeaking(at: .immediate)
        routeDestination = nil
        currentIncidents = []
        lastRecalculationTime = nil
    }
    
    func updateLocation(_ location: CLLocation) {
        guard isNavigating, let route = currentRoute else { return }
        
        currentSpeed = location.speed >= 0 ? location.speed : 0
        
        // Find current position along route - only check nearby steps for efficiency
        let remainingSteps = max(0, routeSteps.count - currentStepIndex)
        let maxStepsToCheck = min(5, remainingSteps)
        var closestStepIndex = currentStepIndex
        var minDistance = CLLocationDistance.greatestFiniteMagnitude
        
        for i in 0..<maxStepsToCheck {
            let index = currentStepIndex + i
            if index < routeSteps.count {
                let distance = distanceToPolyline(location, polyline: routeSteps[index].polyline)
                if distance < minDistance {
                    minDistance = distance
                    closestStepIndex = index
                }
            }
        }
        
        // Update current step if we've progressed
        if closestStepIndex > currentStepIndex {
            currentStepIndex = closestStepIndex
            updateNextInstruction()
            announceNextInstruction()
        }
        
        // Calculate remaining distance efficiently
        var distanceRemaining: CLLocationDistance = 0
        if currentStepIndex < routeSteps.count {
            // Sum remaining steps
            for i in currentStepIndex..<routeSteps.count {
                distanceRemaining += routeSteps[i].distance
            }
            
            // Calculate distance to next turn and adjust total
            let currStep = routeSteps[currentStepIndex]
            let pc2 = currStep.polyline.pointCount
            let turnCoord = pc2 > 0 ? currStep.polyline.points()[pc2 - 1].coordinate : currStep.polyline.coordinate
            let nextStepLocation = CLLocation(latitude: turnCoord.latitude, longitude: turnCoord.longitude)
            nextTurnDistance = location.distance(from: nextStepLocation)
            
            // Adjust remaining distance by subtracting completed portion of current step
            // Guard against negative values from GPS inaccuracy
            let completedDistance = max(0, routeSteps[currentStepIndex].distance - nextTurnDistance)
            distanceRemaining -= completedDistance
        }
        
        remainingDistance = max(0, distanceRemaining)
        
        // Estimate time remaining
        if currentSpeed > 0 {
            estimatedTimeRemaining = remainingDistance / currentSpeed
        } else {
            // Use proportional estimate based on remaining distance
            if route.distance > 0 {
                estimatedTimeRemaining = (remainingDistance / route.distance) * route.expectedTravelTime
            } else {
                estimatedTimeRemaining = route.expectedTravelTime
            }
        }
        
        // If we've already announced the current step but haven't yet repeated for near-turn,
        // and we're within the repeat threshold, speak the instruction again (short reminder).
        if currentStepIndex == lastAnnouncedStepIndex && lastAnnouncedRepeatStepIndex != currentStepIndex {
            let distanceToManeuver = distanceToNextSignificantManeuver(useRemainingPortion: true)
            if distanceToManeuver > 0 && distanceToManeuver <= Self.repeatAnnounceDistanceThreshold {
                let repeatAnnouncement = buildInstructionAnnouncement(includeDistance: true, useRemainingDistance: true)
                queueAnnouncement(repeatAnnouncement, priority: true)
                lastAnnouncedRepeatStepIndex = currentStepIndex
            }
        }
        
        // Check if user has deviated from the current route
        checkForRouteDeviation(location)
    }
    
    func checkForNearbyIncidents(userLocation: CLLocation, incidents: [UserIncident]) {
        guard isNavigating else { return }
        
        for incident in incidents {
            let incidentLocation = CLLocation(
                latitude: incident.coordinate.latitude,
                longitude: incident.coordinate.longitude
            )
            let distance = userLocation.distance(from: incidentLocation)
            
            // Announce if within 500 meters and not already announced
            if distance < 500 && !lastAnnouncedIncidents.contains(incident.id) {
                announceIncident(incident, distance: distance)
                lastAnnouncedIncidents.insert(incident.id)
            }
        }
    }
    
    private func checkForRouteDeviation(_ location: CLLocation) {
        guard isNavigating, let route = currentRoute, !isRecalculating else { return }
        
        // Enforce cooldown to avoid repeated recalculations
        if let lastTime = lastRecalculationTime, Date().timeIntervalSince(lastTime) < Self.recalculationCooldown {
            return
        }
        
        // Check how far user is from the full route polyline
        let distanceFromRoute = distanceToPolyline(location, polyline: route.polyline)
        if distanceFromRoute > Self.routeDeviationThreshold {
            recalculateRoute(from: location)
        }
    }
    
    private func recalculateRoute(from location: CLLocation) {
        guard let destination = routeDestination else { return }
        
        isRecalculating = true
        lastRecalculationTime = Date()
        queueAnnouncement("Recalculating route", priority: true)
        
        // Use device course as a usable heading whenever CLLocation provides a valid course (>= 0).
        // This ensures we prefer routes that align with the direction the user is actually facing,
        // even if their instantaneous speed is low (e.g., slowing for a traffic light). If the
        // system cannot provide a valid course value, we pass nil to skip the direction bias.
        let userHeading: Double? = location.course >= 0 ? location.course : nil
        
        requestDirections(from: location.coordinate, to: destination, avoiding: currentIncidents, userHeading: userHeading) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRecalculating = false
                if case .success = result {
                    // requestDirections already updated route/steps/currentStepIndex=0
                    // Reset announcement tracking so new route steps are announced
                    self.lastAnnouncedStepIndex = -1
                    self.lastAnnouncedRepeatStepIndex = -1
                    self.announceNextInstruction()
                }
            }
        }
    }
    
    private func updateNextInstruction() {
        if currentStepIndex < routeSteps.count {
            let step = routeSteps[currentStepIndex]
            nextInstruction = step.instructions.isEmpty ? "Continue on route" : step.instructions
        } else {
            nextInstruction = "Arriving at destination"
        }
    }
    
    private func announceNextInstruction() {
        // Only do the main announcement once per step
        guard currentStepIndex != lastAnnouncedStepIndex else { return }
        lastAnnouncedStepIndex = currentStepIndex
        // Reset the repeat tracker for the new step
        lastAnnouncedRepeatStepIndex = -1

        // Build announcement including distance to next turn when available
        // For the initial announcement prefer the full-step distance so it doesn't underdescribe
        let announcement = buildInstructionAnnouncement(includeDistance: true, useRemainingDistance: false)
        queueAnnouncement(announcement, priority: true)
    }

    /// Build a spoken instruction for the current step, optionally including a speech-friendly distance.
    private func buildInstructionAnnouncement(includeDistance: Bool, useRemainingDistance: Bool = true) -> String {
        if currentStepIndex < routeSteps.count {
            let step = routeSteps[currentStepIndex]
            let instr = step.instructions.isEmpty ? "Continue on route" : step.instructions
            if includeDistance {
                let distanceToManeuver = distanceToNextSignificantManeuver(useRemainingPortion: useRemainingDistance)
                if distanceToManeuver > 0 {
                    let distancePhrase = formatDistanceForSpeech(distanceToManeuver)
                    return "In \(distancePhrase), \(instr)"
                }
            }
            return instr
        } else {
            return "Arriving at destination"
        }
    }
    
    /// Compute the distance (meters) from current position to the next significant maneuver.
    /// If `useRemainingPortion` is true, use the measured remainder of the current step (nextTurnDistance)
    /// when available; otherwise sum full step distances for an initial, larger announcement.
    private func distanceToNextSignificantManeuver(useRemainingPortion: Bool) -> CLLocationDistance {
        guard !routeSteps.isEmpty else { return 0 }

        // Find index of next step with a meaningful instruction (not just a blank/continue placeholder).
        // Prefer 'major' maneuvers (turn/exit/merge/onto/take/roundabout/ramp/fork/intersection) to avoid very short
        // preliminary steps that underdescribe the distance.
        var targetIndex: Int? = nil
        var fallbackIndex: Int? = nil
        let majorKeywords = ["turn", "exit", "merge", "onto", "take", "roundabout", "ramp", "fork", "intersection"]
        for idx in currentStepIndex..<routeSteps.count {
            let s = routeSteps[idx]
            let instr = s.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
            if instr.isEmpty || instr.lowercased() == "continue on route" {
                continue
            }
            if fallbackIndex == nil {
                fallbackIndex = idx
            }
            let lower = instr.lowercased()
            for kw in majorKeywords {
                if lower.contains(kw) {
                    targetIndex = idx
                    break
                }
            }
            if targetIndex != nil { break }
        }
        if targetIndex == nil {
            // If we still haven't found a major maneuver, pick the first step that's at least a threshold away
            let distanceThreshold: CLLocationDistance = 500.0 // meters
            var cumDistance: CLLocationDistance = 0
            var foundByDistance: Int? = nil
            for i in currentStepIndex..<routeSteps.count {
                cumDistance += routeSteps[i].distance
                if cumDistance >= distanceThreshold {
                    foundByDistance = i
                    break
                }
            }
            if let found = foundByDistance {
                targetIndex = found
            } else {
                targetIndex = fallbackIndex
            }
        }

        // Ensure we have a concrete index to work with
        let tIndex = targetIndex ?? (routeSteps.count - 1)

        var distance: CLLocationDistance = 0
        if useRemainingPortion {
            // Use measured remaining from nextTurnDistance if we have it, otherwise full current step
            if nextTurnDistance > 0 {
                distance += nextTurnDistance
            } else {
                distance += routeSteps[currentStepIndex].distance
            }
            if tIndex > currentStepIndex {
                for i in (currentStepIndex + 1)...tIndex {
                    distance += routeSteps[i].distance
                }
            }
        } else {
            // Sum full step distances from current to target for initial announcement
            for i in currentStepIndex...tIndex {
                distance += routeSteps[i].distance
            }
        }

        // Check for U-turns: if the next significant maneuver is a U-turn, we adjust the distance
        // announcement to cover the entire segment to avoid underreporting.
        if uTurnStepIndices.contains(tIndex) {
            distance += routeSteps[tIndex].distance
        }

        return distance
    }
    
    /// Format distance into a short, speech-friendly phrase: "about 200 feet" or "about 0.2 miles".
    private func formatDistanceForSpeech(_ distance: CLLocationDistance) -> String {
        // Use feet for small distances (< 0.1 miles), otherwise use miles with one decimal.
        let miles = distance / Self.metersToMiles
        if miles < 0.1 {
            let feet = max(1, Int(distance * Self.metersToFeet))
            return "about \(feet) feet"
        } else {
            return String(format: "about %.1f miles", miles)
        }
    }
    
    private func announceIncident(_ incident: UserIncident, distance: CLLocationDistance) {
        let distanceInFeet = Int(distance * Self.metersToFeet)
        let announcement = "Warning: \(incident.type) ahead in approximately \(distanceInFeet) feet"
        queueAnnouncement(announcement, priority: false)
    }
    
    private func queueAnnouncement(_ text: String, priority: Bool) {
        // Ensure speech interactions happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if priority {
                // Priority announcements (turns) interrupt current speech
                if self.speechSynthesizer.isSpeaking {
                    self.speechSynthesizer.stopSpeaking(at: .immediate)
                }
                self.announcementQueue.removeAll()
                self.speak(text)
            } else {
                // Non-priority announcements (incidents) are queued
                if !self.speechSynthesizer.isSpeaking && !self.isProcessingAnnouncement {
                    self.speak(text)
                } else {
                    self.announcementQueue.append(text)
                }
            }
        }
    }
    
    private func speak(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isProcessingAnnouncement = true
            // Ensure audio session is active before speaking
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                // Non-fatal
            }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            self.speechSynthesizer.speak(utterance)
        }
    }
    
    private func processNextAnnouncement() {
        guard !announcementQueue.isEmpty, !speechSynthesizer.isSpeaking else {
            isProcessingAnnouncement = false
            return
        }
        let nextAnnouncement = announcementQueue.removeFirst()
        speak(nextAnnouncement)
    }
    
    func formatDistance(_ distance: CLLocationDistance) -> String {
        let miles = distance / Self.metersToMiles
        if miles < 0.1 {
            let feet = Int(distance * Self.metersToFeet)
            return "\(feet) ft"
        } else {
            return String(format: "%.1f mi", miles)
        }
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    func formatSpeed(_ speed: Double) -> String {
        // Speed is in m/s. Convert to mph and format.
        let mph = max(0, speed) * Self.metersPerSecondToMph
        if mph < 1.0 {
            return "0 mph"
        } else {
            return String(format: "%.0f mph", mph)
        }
    }

    /// Compute the initial bearing (0-360°) of a route by sampling points along the start of its polyline.
    /// Walks up to `routeInitialBearingSampleDistance` meters from the first point to get a stable bearing.
    private func initialBearing(of route: MKRoute) -> Double {
        let polyline = route.polyline
        let pointCount = polyline.pointCount
        guard pointCount >= 2 else { return 0 }
        let points = polyline.points()
        let startCoord = points[0].coordinate
        let startLocation = CLLocation(latitude: startCoord.latitude, longitude: startCoord.longitude)
        for i in 1..<pointCount {
            let coord = points[i].coordinate
            let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            if startLocation.distance(from: loc) >= Self.routeInitialBearingSampleDistance {
                return bearing(from: startCoord, to: coord)
            }
        }
        return bearing(from: startCoord, to: points[pointCount - 1].coordinate)
    }

    /// Compute the forward bearing in degrees (0-360) from one coordinate to another.
    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Compute the minimum angular difference between two bearings (result in range 0-180°).
    private func angularDifference(_ a: Double, _ b: Double) -> Double {
        var diff = (a - b).truncatingRemainder(dividingBy: 360)
        if diff < 0 { diff += 360 }
        if diff > 180 { diff = 360 - diff }
        return diff
    }

    private func distanceToPolyline(_ location: CLLocation, polyline: MKPolyline) -> CLLocationDistance {
        let pc = polyline.pointCount
        guard pc > 0 else { return .greatestFiniteMagnitude }
        let pts = polyline.points()
        let p = MKMapPoint(location.coordinate)
        var minDist = p.distance(to: pts[0])
        for i in 0..<(pc - 1) {
            let a = pts[i]
            let b = pts[i + 1]
            let abx = b.x - a.x, aby = b.y - a.y
            let len2 = abx * abx + aby * aby
            if len2 > 0 {
                let t = max(0, min(1, ((p.x - a.x) * abx + (p.y - a.y) * aby) / len2))
                let closest = MKMapPoint(x: a.x + t * abx, y: a.y + t * aby)
                let d = p.distance(to: closest)
                if d < minDist { minDist = d }
            }
        }
        return minDist
    }
    
    // Store last known location used for trimming when a route is first obtained
    private var lastKnownLocation: CLLocation?
    
    /// Compute and publish the completed and remaining polylines by projecting the user's
    /// location onto the current step polyline and splitting there. This produces smoother
    /// visual trimming compared to using nearest vertex only.
    func updateRemainingPolyline(using location: CLLocation) {
        guard let _ = currentRoute, !routeSteps.isEmpty else {
            remainingRoutePolyline = nil
            completedRoutePolyline = nil
            return
        }

        let userPoint = MKMapPoint(location.coordinate)
        var completedCoords: [CLLocationCoordinate2D] = []
        var remainingCoords: [CLLocationCoordinate2D] = []

        func appendStepFullCoords(_ step: MKRoute.Step, to array: inout [CLLocationCoordinate2D]) {
            let pc = step.polyline.pointCount
            guard pc > 0 else { return }
            let pts = step.polyline.points()
            for i in 0..<pc { array.append(pts[i].coordinate) }
        }

        // Add all steps before current as completed
        if currentStepIndex > 0 {
            for i in 0..<min(currentStepIndex, routeSteps.count) {
                appendStepFullCoords(routeSteps[i], to: &completedCoords)
            }
        }

        // Project onto current step
        let currStep = routeSteps[currentStepIndex]
        let pc = currStep.polyline.pointCount
        if pc > 0 {
            let pts = currStep.polyline.points()
            var bestDist = Double.greatestFiniteMagnitude
            var bestSegment = 0
            var bestT: Double = 0
            for i in 0..<(pc - 1) {
                let a = pts[i]
                let b = pts[i + 1]
                let ax = a.x, ay = a.y
                let bx = b.x, by = b.y
                let vx = bx - ax, vy = by - ay
                let len2 = vx * vx + vy * vy
                var t: Double = 0
                if len2 > 0 {
                    t = Double(((userPoint.x - ax) * vx + (userPoint.y - ay) * vy) / len2)
                    t = max(0, min(1, t))
                }
                let proj = MKMapPoint(x: ax + vx * CGFloat(t), y: ay + vy * CGFloat(t))
                let d = userPoint.distance(to: proj)
                if d < bestDist { bestDist = d; bestSegment = i; bestT = t }
            }

            // Completed: points up to projection
            for j in 0...bestSegment { completedCoords.append(pts[j].coordinate) }
            let a = pts[bestSegment]; let b = pts[bestSegment + 1]
            let proj = MKMapPoint(x: a.x + (b.x - a.x) * CGFloat(bestT), y: a.y + (b.y - a.y) * CGFloat(bestT))
            completedCoords.append(proj.coordinate)

            // Remaining begins at projection
            remainingCoords.append(proj.coordinate)
            for j in (bestSegment + 1)..<pc { remainingCoords.append(pts[j].coordinate) }
        }

        // Append subsequent steps entirely to remaining
        if currentStepIndex + 1 < routeSteps.count {
            for i in (currentStepIndex + 1)..<routeSteps.count { appendStepFullCoords(routeSteps[i], to: &remainingCoords) }
        }

        completedRoutePolyline = completedCoords.count > 1 ? MKPolyline(coordinates: completedCoords, count: completedCoords.count) : nil
        remainingRoutePolyline = remainingCoords.count > 1 ? MKPolyline(coordinates: remainingCoords, count: remainingCoords.count) : nil
    }

    // Backwards-compatible wrappers some code might call
    func updatePolyline(using location: CLLocation) { updateRemainingPolyline(using: location) }
    func updatePolyline() { if let l = lastKnownLocation { updateRemainingPolyline(using: l) } }

    /// Return "left"/"right" for the turning direction of a step if it can be determined geometrically,
    /// otherwise nil. Uses the sign of the signed angle between the step's start and end bearings.
    func stepTurnDirection(at index: Int) -> String? {
        guard index >= 0 && index < routeSteps.count else { return nil }
        let step = routeSteps[index]
        let pc = step.polyline.pointCount
        guard pc >= 2 else { return nil }
        let pts = step.polyline.points()
        let startA = pts[0].coordinate
        let startB = pts[min(1, pc - 1)].coordinate
        let endA = pts[max(0, pc - 2)].coordinate
        let endB = pts[pc - 1].coordinate
        let startBearing = bearing(from: startA, to: startB)
        let endBearing = bearing(from: endA, to: endB)
        // Signed difference in range (-180, 180]
        var diff = (endBearing - startBearing).truncatingRemainder(dividingBy: 360)
        if diff <= -180 { diff += 360 }
        if diff > 180 { diff -= 360 }
        if diff < 0 { return "left" }
        if diff > 0 { return "right" }
        return nil
    }

}

// MARK: - AVSpeechSynthesizerDelegate
extension DirectionsManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        processNextAnnouncement()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // Continue processing queue if speech was cancelled
        processNextAnnouncement()
    }
}
