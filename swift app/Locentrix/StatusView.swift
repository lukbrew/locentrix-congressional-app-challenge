import SwiftUI

struct StatusView: View {
    @State private var email = UserDefaults.standard.string(forKey: "userEmail") ?? ""
    @State private var cookie = UserDefaults.standard.string(forKey: "userCookie") ?? ""
    @State private var isSignedIn = false
    @State private var showAuthenticationView = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertColor: Color = .red

    var body: some View {
        VStack(spacing: 0) {
            StatusHeaderView()
                .frame(height: 60)
            Spacer()
            if !isSignedIn {
                Text("You need to be signed in to use status checks.")
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Sign In") {
                    showAuthenticationView = true
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .sheet(isPresented: $showAuthenticationView) {
                    AuthenticationView(isSignedIn: $isSignedIn)
                }
            } else {
                VStack(spacing: 16) {
                    Button("Check Server Status") {
                        checkServerStatus()
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)

                    Button("Check Session Validity") {
                        checkSessionValidity()
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)

                    Button("Check If Account Blocked") {
                        checkIfBlocked()
                    }
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(8)

                    Button("Check If Account Exists") {
                        checkIfAccountExists()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            Spacer()
        }
        .padding([.bottom])
        .onAppear {
            checkIfSignedIn()
        }
        .overlay(
            CustomAlertView(message: alertMessage, color: alertColor, showAlert: $showAlert)
        )
    }

    func checkIfSignedIn() {
        if let savedEmail = UserDefaults.standard.string(forKey: "userEmail"),
           let savedCookie = UserDefaults.standard.string(forKey: "userCookie"),
           !savedEmail.isEmpty, !savedCookie.isEmpty {
            email = savedEmail
            cookie = savedCookie
            isSignedIn = true
        } else {
            isSignedIn = false
        }
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "userCookie")
        isSignedIn = false
        email = ""
        cookie = ""
    }

    func checkServerStatus() {
        guard let url = URL(string: "https://locentrix.legendarycoding.com/api/status") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    showAlertWithMessage("Servers are up!", color: .green)
                } else {
                    showAlertWithMessage("Servers are down.", color: .red)
                }
            }
        }.resume()
    }

    func checkSessionValidity() {
        guard !email.isEmpty, !cookie.isEmpty else {
            showAlertWithMessage("No email or cookie found. Please sign in.", color: .red)
            return
        }
        let urlString = "https://locentrix.legendarycoding.com/api/user/status/iscookievalid"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "cookie": cookie]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let response = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed == "true" {
                        showAlertWithMessage("Session is valid.", color: .green)
                    } else {
                        showAlertWithMessage("Session is invalid. Signing out...", color: .red)
                        signOut()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    showAlertWithMessage("Session is invalid. Signing out...", color: .red)
                    signOut()
                }
            }
        }.resume()
    }

    func checkIfBlocked() {
        guard !email.isEmpty, !cookie.isEmpty else {
            showAlertWithMessage("No email or cookie found. Please sign in.", color: .red)
            return
        }
        let urlString = "https://locentrix.legendarycoding.com/api/user/status/isblocked"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "cookie": cookie]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let response = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed == "false" {
                        showAlertWithMessage("Your account is not blocked.", color: .green)
                    } else if trimmed == "true" {
                        showAlertWithMessage("Your account is blocked. Signing out...", color: .red)
                        signOut()
                    } else {
                        showAlertWithMessage("Session is invalid. Signing out...", color: .red)
                        signOut()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    showAlertWithMessage("Session is invalid. Signing out...", color: .red)
                    signOut()
                }
            }
        }.resume()
    }

    func checkIfAccountExists() {
        guard !email.isEmpty else {
            showAlertWithMessage("No email found. Please sign in.", color: .red)
            return
        }
        let urlString = "https://locentrix.legendarycoding.com/api/user/status/userexists"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let response = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed == "true" {
                        showAlertWithMessage("Your account exists.", color: .green)
                    } else {
                        showAlertWithMessage("Your account was deleted. Signing out...", color: .red)
                        signOut()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    showAlertWithMessage("Could not check account existence.", color: .red)
                }
            }
        }.resume()
    }

    func showAlertWithMessage(_ message: String, color: Color) {
        alertMessage = message
        alertColor = color
        showAlert = true
    }
}
