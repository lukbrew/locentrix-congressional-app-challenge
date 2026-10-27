import SwiftUI


struct MainTabView: View {
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertColor: Color = .red
    @State private var hasCheckedVersion = false
    @State private var showUpdateMessage = false
    @State private var updateMessage = ""

    var body: some View {
        ZStack {
            TabView {
                NavigationStack {
                    Publicmap()
                        .frame(maxHeight: .infinity)
                        .padding(.top, 0)
                        .navigationBarHidden(true)
                }
                .tabItem {
                    Label("Public", systemImage: "mappin.circle.fill")
                }
                
                NavigationStack {
                    Privatemap()
                        .frame(maxHeight: .infinity)
                        .padding(.top, 0)
                        .navigationBarHidden(true)
                }
                .tabItem {
                    Label("Private", systemImage: "lock.fill")
                }

                NavigationStack {
                    ClearData()
                        .frame(maxHeight: .infinity)
                        .padding(.top, 0)
                        .navigationBarHidden(true)
                }
                .tabItem {
                    Label("Clear Info", systemImage: "person.2.badge.key")
                }
                
                NavigationStack {
                    StatusView()
                        .frame(maxHeight: .infinity)
                        .padding(.top, 0)
                        .navigationBarHidden(true)
                }
                .tabItem {
                    Label("Status", systemImage: "paperplane.fill")
                }
                NavigationStack {
                    SettingsView()
                        .frame(maxHeight: .infinity)
                        .padding(.top, 0)
                        .navigationBarHidden(true)
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
            }
            
            InAppNotificationView()
            CustomAlertView(message: alertMessage, color: alertColor, showAlert: $showAlert)
        }
        .onAppear {
            if !hasCheckedVersion {
                hasCheckedVersion = true
                checkServerAndVersion()
            }
        }
        .fullScreenCover(isPresented: $showUpdateMessage) {
            VStack {
                Text("Important Message")
                    .font(.largeTitle)
                    .padding()
                Text(updateMessage)
                    .padding()
                Button("Continue") {
                    showUpdateMessage = false
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
    }

    private func checkServerAndVersion() {
        guard let statusURL = URL(string: "https://locentrix.legendarycoding.com/api/status") else { return }
        URLSession.shared.dataTask(with: statusURL) { _, response, _ in
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            guard let versionURL = URL(string: "https://locentrix.legendarycoding.com/api/status/version") else { return }
            URLSession.shared.dataTask(with: versionURL) { data, _, _ in
                guard let data = data,
                      let versionString = String(data: data, encoding: .utf8),
                      let version = Int(versionString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    checkForUpdateMessage()
                    return
                }
                if version > 1 {
                    DispatchQueue.main.async {
                        UserDefaults.standard.removeObject(forKey: "userEmail")
                        UserDefaults.standard.removeObject(forKey: "userCookie")
                        alertMessage = "You will be unable to use online features until you update your app."
                        alertColor = .red
                        showAlert = true
                    }
                }
                checkForUpdateMessage()
            }.resume()
        }.resume()
    }

    private func checkForUpdateMessage() {
        guard let url = URL(string: "https://locentrix.legendarycoding.com/api/message/update") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["version": 1])
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil,
                  let response = String(data: data, encoding: .utf8) else { return }
            let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != "false" && !trimmed.isEmpty && trimmed.count <= 500 {
                DispatchQueue.main.async {
                    updateMessage = trimmed
                    showUpdateMessage = true
                }
            }
        }.resume()
    }
}
