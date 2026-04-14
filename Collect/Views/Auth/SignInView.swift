import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Full-screen gradient background matching the icon
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.12, blue: 0.31),
                             Color(red: 0.12, green: 0.47, blue: 0.86)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Icon + wordmark
                    VStack(spacing: 20) {
                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 110, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 8)

                        VStack(spacing: 6) {
                            Text("Collect")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text("Catalog your spaces with AI")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }

                    Spacer().frame(height: 52)

                    // Form card
                    VStack(spacing: 14) {
                        TextField("Email", text: $email)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(.white)
                            .tint(.white)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)

                        SecureField("Password", text: $password)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(.white)
                            .tint(.white)
                            .textContentType(.password)

                        if let error = authService.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Color(red: 1.0, green: 0.5, blue: 0.5))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }

                        Button {
                            Task { await authService.signIn(email: email, password: password) }
                        } label: {
                            Group {
                                if authService.isLoading {
                                    ProgressView().tint(.blue)
                                } else {
                                    Text("Sign In")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white)
                            .foregroundStyle(Color(red: 0.12, green: 0.47, blue: 0.86))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(email.isEmpty || password.isEmpty || authService.isLoading)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 32)

                    Spacer()

                    VStack(spacing: 16) {
                        // Try without account
                        Button {
                            Task { await authService.signInAsGuest() }
                        } label: {
                            Text("Try Now")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(.white.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(.horizontal, 32)

                        // Sign up link
                        Button {
                            showSignUp = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("Don't have an account?")
                                    .foregroundStyle(.white.opacity(0.65))
                                Text("Sign Up")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(.bottom, 8)

                // Version string — reads live from bundle
                Text(versionString)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.bottom, 20)
                }
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView()
            }
        }
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }
}
