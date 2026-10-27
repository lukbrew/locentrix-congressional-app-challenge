import SwiftUI

struct AuthenticationView: View {
    @State private var email = ""
    @State private var verificationCode = ""
    @State private var isRegistered = false
    @State private var errorMessage: String?
    @Binding var isSignedIn: Bool

    var body: some View {
        VStack(spacing: 0) {
            AuthHeaderView()
                .frame(height: 60)

            Spacer()

            if !isRegistered {
                Text("Please enter your email. This will be used for verification purposes.")
                TextField("Enter your email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                Button("Sign In") {
                    signInWithEmail()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            } else {
                Text("A verification code has been sent to your email. Please enter it below. After signing in, please relaunch this app for access to all features.")
                TextField("Enter verification code", text: $verificationCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                Button("Verify") {
                    verifyCode()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding([.bottom])
    }

    func signInWithEmail() {
        guard !email.isEmpty else {
            errorMessage = "Please enter a valid email."
            return
        }
        let urlString = "https://Locentrix.legendarycoding.com/api/user/addition/register"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email.lowercased()]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let response = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedResponse == "false" {
                        errorMessage = "Server error. Are you sure you entered a valid email? Please try again later."
                    } else {
                        isRegistered = true
                }
                    }
            }
        }.resume()
    }

    func verifyCode() {
        guard !email.isEmpty, !verificationCode.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }

        let urlString = "https://Locentrix.legendarycoding.com/api/user/addition/verify"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email.lowercased(), "code": verificationCode]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let response = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let newCookie = Int(trimmedResponse) {
                        isSignedIn = true
                        UserDefaults.standard.set(email.lowercased(), forKey: "userEmail")
                        UserDefaults.standard.set(newCookie, forKey: "userCookie")
                    } else {
                        errorMessage = "Invalid verification code. Try again."
                    }
                }
            }
        }.resume()
    }
}
