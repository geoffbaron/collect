import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var showOnboarding = false

    var body: some View {
        Group {
            if authService.isAuthenticated {
                PropertyListView()
                    .onAppear { checkOnboarding() }
            } else {
                SignInView()
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
                .interactiveDismissDisabled(false)
        }
    }

    private func checkOnboarding() {
        Task {
            let hasKey = await AIService.shared.hasAPIKey
            let seenOnboarding = UserDefaults.standard.bool(forKey: "collect_onboarding_seen")
            if !hasKey && !seenOnboarding {
                UserDefaults.standard.set(true, forKey: "collect_onboarding_seen")
                await MainActor.run { showOnboarding = true }
            }
        }
    }
}
