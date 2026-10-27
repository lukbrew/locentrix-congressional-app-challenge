import SwiftUI

@main
struct MyApp: App {
    @State private var isFirstLaunch: Bool = UserDefaults.standard.object(forKey: "isFirstLaunch") as? Bool ?? true
    @State private var showLaunchMessage: Bool = false
    @State private var launchMessage: String = ""

    var body: some Scene {
        WindowGroup {
            if isFirstLaunch {
                FirstLaunchGuide(isFirstLaunch: $isFirstLaunch)
                    .onDisappear {
                        checkForMessageUpdate()
                    }
            } else if showLaunchMessage && !launchMessage.isEmpty {
                LaunchMessage(isFirstLaunch: $isFirstLaunch, message: launchMessage)
                    .onDisappear {
                        showLaunchMessage = false
                    }
            } else {
                MainTabView()
            }
        }
    }

    private func checkForMessageUpdate() {
        guard let url = URL(string: "https://locentrix.legendarycoding.com/api/message") else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil,
                  let fetchedMessage = String(data: data, encoding: .utf8) else { return }

            DispatchQueue.main.async {
                let savedMessage = UserDefaults.standard.string(forKey: "launchMessage") ?? ""

                if fetchedMessage != savedMessage {
                    launchMessage = fetchedMessage
                    showLaunchMessage = true
                    UserDefaults.standard.set(fetchedMessage, forKey: "launchMessage")
                }
            }
        }.resume()
    }
}
