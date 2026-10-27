import SwiftUI

struct LaunchMessage: View {
    @Binding var isFirstLaunch: Bool
    @State var message: String
    @State private var showMessage: Bool = true

    var body: some View {
        if showMessage {
            VStack {
                Text("Important Message")
                    .font(.largeTitle)
                    .padding()

                Text(message)
                    .padding()

                Button("Continue") {
                    showMessage = false
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
    }
}
