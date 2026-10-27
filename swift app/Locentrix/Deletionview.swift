import SwiftUI

struct DeletionView: View {
    @State private var email = UserDefaults.standard.string(forKey: "userEmail") ?? ""
    @State private var verificationCode = ""
    @State private var isSignedIn = false
    @State private var isCodeSent = false
    @State private var showAuthenticationView = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertColor: Color = .red

    var body: some View {
        VStack(spacing: 0) {
            DeletionHeaderView()
                .frame(height: 60)

            Spacer()

            if !isSignedIn {
                Text("You need to be signed in to delete your account.")
                    .multilineTextAlignment(.center)
                        .lineLimit(nil)
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
            } else if !isCodeSent {
                Text("A verification code will be sent to your email to confirm account deletion. If you just signed in, please relaunch the app now before pressing this button.")
                    .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .padding()
                Button("Send Verification Code") {
                    sendVerificationCode()
                }
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
            } else {
                Text("Enter the verification code sent to your email to delete your account.")
                    .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .padding()
                TextField("Enter verification code", text: $verificationCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                Button("Delete Account") {
                    verifyAndDeleteAccount()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .onAppear {
            checkIfSignedIn()
        }
        .overlay(
            CustomAlertView(message: alertMessage, color: alertColor, showAlert: $showAlert)
        )
    }

    func checkIfSignedIn() {
        if let savedEmail = UserDefaults.standard.string(forKey: "userEmail"), !savedEmail.isEmpty {
            email = savedEmail
            isSignedIn = true
        } else {
            isSignedIn = false
        }
    }

    func sendVerificationCode() {
        guard !email.isEmpty else {
            showAlertWithMessage("No email found. Please sign in first. If you just signed in, pelase fully close out of this app and open it again.", color: .red)
            return
        }

        let urlString = "https://locentrix.legendarycoding.com/api/user/removal/usrremove"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email.lowercased()]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                showAlertWithMessage("Network error: \(error.localizedDescription)", color: .red)
                return
            }

            if let data = data, let response = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedResponse == "true" {
                        isCodeSent = true
                    } else {
                        showAlertWithMessage("Failed to send verification code. Try again.", color: .red)
                    }
                }
            }
        }.resume()
    }

    func verifyAndDeleteAccount() {
        guard !email.isEmpty, !verificationCode.isEmpty else {
            showAlertWithMessage("Please fill in all fields.", color: .red)
            return
        }

        let urlString = "https://locentrix.legendarycoding.com/api/user/removal/usrremoveverify"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email.lowercased(), "code": verificationCode]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                showAlertWithMessage("Network error: \(error.localizedDescription)", color: .red)
                return
            }

            if let data = data, let response = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    if response.trimmingCharacters(in: .whitespacesAndNewlines) == "true" {
                        showAlertWithMessage("Account successfully deleted. Relaunch app.", color: .green)
                        UserDefaults.standard.removeObject(forKey: "userEmail")
                        isSignedIn = false
                        isCodeSent = false
                    } else {
                        showAlertWithMessage("Invalid verification code. Try again.", color: .red)
                    }
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
