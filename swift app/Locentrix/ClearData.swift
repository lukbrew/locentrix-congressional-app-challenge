import SwiftUI

struct ClearData: View {
    @State private var email: String = UserDefaults.standard.string(forKey: "userEmail") ?? ""
    @State private var errorMessage: String?
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var alertColor: Color = .red
    @State private var showDeletionView: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ClearDataHeader()
                .frame(height: 60)
                .background(Color.blue)

            Spacer()

            VStack {
                Text("Sign out from this device. Please close and reopen the app after pressing this button.")
                Button("Sign Out") {
                    signOut()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()

            VStack {
                Text("Sign out and remove all incidents logged from this device.")
                Button("Clear All Data") {
                    clearAllData()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()

            VStack {
                Text("Delete private incidents stored on this device.")
                NavigationLink(destination: DeletePrivateIncident()) {
                    Text("Delete Incidents")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()

            VStack {
                Text("Delete account, clear stored user data, and sign out. This is a formal request for account/data deletion, but your email may be stored for a short amount of time to prevent abuse of this service.")
                Button("Delete Account") {
                    showDeletionView = true
                }
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .sheet(isPresented: $showDeletionView) {
                    DeletionView()
                }
            }
            .padding()

            Spacer()
        }
        .padding([.bottom])
        .overlay(
            CustomAlertView(message: alertMessage, color: alertColor, showAlert: $showAlert)
        )
    }
    
    func signOut() {
        UserDefaults.standard.removeObject(forKey: "userEmail")
        email = ""
        alertMessage = "You have been signed out successfully. Relaunch app."
        alertColor = .green
        showAlert = true
    }
    
    func clearAllData() {
        if let appDomain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: appDomain)
            alertMessage = "All data has been cleared successfully. Relaunch app."
            alertColor = .green
        } else {
            alertMessage = "Failed to clear data."
            alertColor = .red
        }
        showAlert = true
    }
}
