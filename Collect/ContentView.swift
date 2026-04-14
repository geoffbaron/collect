import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        Group {
            if authService.isAuthenticated {
                PropertyListView()
            } else {
                SignInView()
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
    }
}
