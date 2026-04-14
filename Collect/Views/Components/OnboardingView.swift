import SwiftUI

/// Shown on first launch to get the Gemini API key.
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var apiKey = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.12, blue: 0.31),
                             Color(red: 0.12, green: 0.47, blue: 0.86)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Icon
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 6)

                    Spacer().frame(height: 32)

                    VStack(spacing: 8) {
                        Text("One Last Thing")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Collect uses Google Gemini to identify assets in your rooms. Add your free API key to get started.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer().frame(height: 40)

                    VStack(spacing: 12) {
                        SecureField("Paste your Gemini API key", text: $apiKey)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(.white)
                            .tint(.white)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Button {
                            saveAndContinue()
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView().tint(.blue)
                                } else {
                                    Text("Get Started")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white)
                            .foregroundStyle(Color(red: 0.12, green: 0.47, blue: 0.86))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    }
                    .padding(.horizontal, 32)

                    Spacer().frame(height: 20)

                    Button {
                        isPresented = false
                    } label: {
                        Text("Skip for now")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    Spacer()

                    Link("Get a free key at aistudio.google.com →",
                         destination: URL(string: "https://aistudio.google.com/apikey")!)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func saveAndContinue() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        Task {
            await AIService.shared.setAPIKey(trimmed)
            await MainActor.run {
                isSaving = false
                isPresented = false
            }
        }
    }
}
