import SwiftUI
import MapKit

struct DirectionsOverlayView: View {
    @ObservedObject var directionsManager: DirectionsManager = DirectionsManager.shared
    var onEndRoute: () -> Void
    
    var body: some View {
        VStack {
            if directionsManager.isNavigating {
                // Top card with navigation info
                VStack(spacing: 0) {
                    // Next turn instruction
                    HStack {
                        Image(systemName: getTurnIcon())
                            .font(.system(size: 36))
                            .foregroundColor(.blue)
                            .frame(width: 50)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(directionsManager.nextInstruction)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            Text(directionsManager.formatDistance(directionsManager.nextTurnDistance))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    
                    Divider()
                    
                    // Route info bar
                    HStack {
                        // Remaining distance
                        VStack(spacing: 2) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Text(directionsManager.formatDistance(directionsManager.remainingDistance))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Divider()
                            .frame(height: 30)
                        
                        // Remaining time
                        VStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Text(directionsManager.formatTime(directionsManager.estimatedTimeRemaining))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Divider()
                            .frame(height: 30)
                        
                        // Current speed
                        VStack(spacing: 2) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Text(directionsManager.formatSpeed(directionsManager.currentSpeed))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Divider()
                            .frame(height: 30)
                        
                        // End route button
                        Button(action: {
                            onEndRoute()
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                Text("End")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .background(Color(UIColor.systemBackground))
                }
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                .padding()
                
                Spacer()
            }
        }
    }
    
    private func getTurnIcon() -> String {
        let instruction = directionsManager.nextInstruction.lowercased()
        
        if instruction.contains("left") {
            return "arrow.turn.up.left"
        } else if instruction.contains("right") {
            return "arrow.turn.up.right"
        } else if instruction.contains("straight") || instruction.contains("continue") {
            return "arrow.up"
        } else if instruction.contains("u-turn") {
            return "arrow.uturn.left"
        } else if instruction.contains("arrive") || instruction.contains("destination") {
            return "mappin.circle.fill"
        } else {
            return "arrow.up"
        }
    }
}
