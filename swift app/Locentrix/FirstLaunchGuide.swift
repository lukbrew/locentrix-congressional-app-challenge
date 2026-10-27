import SwiftUI


struct FirstLaunchGuide: View {
    @Binding var isFirstLaunch: Bool

    var body: some View {
        VStack {
            Text("Welcome to Locentrix!")
                .font(.largeTitle)
                .padding()

            Text("Here is a quick guide to get you started:")
                .padding()

            VStack(alignment: .leading, spacing: 10) {
                Text("1. **Private Map**: View and report incidents.")
                Text("2. **Public Map**: View public incidents reported by others. This will only be availible upon sign in.")
                Text("3. **Clear Info**: Manage your data and account settings.")
                Text("4. **Sign in and Internet Connection**: Some feature of this app are only available upon sign in. Internet connection is not required, but additional features will be limited. The private map, incident reporting, and notifications will be available offline. However, the map may not display properly and you will not have access to incidents reported by others.")
            }
            .padding()

            Button("Get Started") {
                isFirstLaunch = false
                UserDefaults.standard.set(false, forKey: "isFirstLaunch")
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
}
