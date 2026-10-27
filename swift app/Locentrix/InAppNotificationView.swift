import SwiftUI

struct InAppNotificationView: View {
    @ObservedObject var notificationManager = InAppNotificationManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            if notificationManager.showNotification, let incident = notificationManager.currentIncident {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(getIncidentColor(for: incident.type))
                                .frame(width: 16, height: 16)
                                .padding(.leading, 16)
                            
                            Text(incident.type.uppercased())
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                notificationManager.dismissNotification()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.gray)
                                    .frame(width: 30, height: 30)
                            }
                            .padding(.trailing, 16)
                        }
                        .padding(.vertical, 12)
                        
                        Divider()
                            .padding(.horizontal, 16)
                        
                        HStack(spacing: 0) {
                            Button(action: {
                                notificationManager.handleAgree()
                            }) {
                                HStack {
                                    Image(systemName: "hand.thumbsup.fill")
                                        .font(.system(size: 16))
                                    Text("Agree")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                            .padding(.leading, 16)
                            .padding(.trailing, 8)
                            
                            Button(action: {
                                notificationManager.handleDisagree()
                            }) {
                                HStack {
                                    Image(systemName: "hand.thumbsdown.fill")
                                        .font(.system(size: 16))
                                    Text("Disagree")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                            .padding(.leading, 8)
                            .padding(.trailing, 16)
                        }
                        .padding(.vertical, 12)
                    }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: -2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: notificationManager.showNotification)
            }
        }
        .ignoresSafeArea(.all, edges: .all)
    }
}
