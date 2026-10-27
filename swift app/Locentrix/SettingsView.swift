import SwiftUI
import UserNotifications

struct SettingsView: View {
    @State private var enablePushOutsideApp: Bool = {
        if UserDefaults.standard.object(forKey: "enablePushOutsideApp") == nil {
            UserDefaults.standard.set(true, forKey: "enablePushOutsideApp")
            return true
        }
        return UserDefaults.standard.bool(forKey: "enablePushOutsideApp")
    }()

    @State private var enableTTSAnnouncements: Bool = {
        if UserDefaults.standard.object(forKey: "enableTTSAnnouncements") == nil {
            UserDefaults.standard.set(false, forKey: "enableTTSAnnouncements")
            return false
        }
        return UserDefaults.standard.bool(forKey: "enableTTSAnnouncements")
    }()

    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var alertColor: Color = .green

    var body: some View {
        VStack(spacing: 0) {
            SettingsHeaderView()
                .frame(height: 60)
                .background(Color.blue)

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text("Push Notifications (outside the app)")
                    .font(.headline)

                Text("Allow or disallow push notifications delivered outside the app (system notifications). This does not affect in-app notifications.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Toggle(isOn: $enablePushOutsideApp) {
                    Text(enablePushOutsideApp ? "Enabled" : "Disabled")
                        .fontWeight(.semibold)
                }
                .onChange(of: enablePushOutsideApp) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "enablePushOutsideApp")

                    if newValue {
                        NotificationHelper.requestNotificationPermission()
                        alertMessage = "Push notifications enabled. You may be prompted to allow notifications."
                        alertColor = .green
                        showAlert = true
                    } else {
                        let center = UNUserNotificationCenter.current()
                        center.removeAllPendingNotificationRequests()
                        center.removeAllDeliveredNotifications()

                        alertMessage = "Push notifications disabled. To fully revoke system permission open iOS Settings > Apps > Locentrix > Notifications."
                        alertColor = .red
                        showAlert = true
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))

                #if canImport(UIKit)
                Button("Open iOS Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
                .padding(.top, 8)
                .foregroundColor(.blue)
                #endif

                Divider()
                    .padding(.vertical, 8)

                Text("Text-to-Speech Announcements (while not navigating)")
                    .font(.headline)

                Text("Enable spoken announcements when approaching incidents while not actively navigating. This does not affect announcements during navigation.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Toggle(isOn: $enableTTSAnnouncements) {
                    Text(enableTTSAnnouncements ? "Enabled" : "Disabled")
                        .fontWeight(.semibold)
                }
                .onChange(of: enableTTSAnnouncements) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "enableTTSAnnouncements")

                    if newValue {
                        alertMessage = "Text-to-speech announcements enabled for nearby incidents."
                        alertColor = .green
                        showAlert = true
                    } else {
                        alertMessage = "Text-to-speech announcements disabled."
                        alertColor = .blue
                        showAlert = true
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))

            }
            .padding()

            Spacer()
        }
        .padding([.bottom])
        .overlay(
            CustomAlertView(message: alertMessage, color: alertColor, showAlert: $showAlert)
        )
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
