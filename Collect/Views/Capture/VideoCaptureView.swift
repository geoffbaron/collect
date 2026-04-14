import SwiftUI
import AVFoundation

struct VideoCaptureView: View {
    let room: Room
    let template: PromptTemplate
    let onVideoRecorded: (URL) -> Void

    @EnvironmentObject private var limitsService: LimitsService
    @StateObject private var camera = CameraController()
    @State private var isRecording = false
    @State private var elapsedSeconds = 0
    @State private var timer: Timer?
    @State private var showLimitWarning = false

    private var maxSeconds: Int { limitsService.limits.maxVideoSeconds }
    private var isUnlimited: Bool { limitsService.limits.isVideoUnlimited }

    // Fraction of limit elapsed (0–1), nil when unlimited
    private var progress: Double? {
        guard !isUnlimited, isRecording else { return nil }
        return min(Double(elapsedSeconds) / Double(maxSeconds), 1.0)
    }

    // Warning colour: green → yellow → red
    private var timerColor: Color {
        guard let p = progress else { return .white }
        if p < 0.7  { return .white }
        if p < 0.9  { return .yellow }
        return .red
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: camera.session).ignoresSafeArea()

            VStack {
                // ── Top: timer + limit bar ─────────────────────────────
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        if isRecording {
                            HStack(spacing: 6) {
                                Circle().fill(.red).frame(width: 8, height: 8)
                                Text(timeString(elapsedSeconds))
                                    .foregroundStyle(timerColor)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                if !isUnlimited {
                                    Text("/ \(timeString(maxSeconds))")
                                        .foregroundStyle(.white.opacity(0.5))
                                        .font(.caption)
                                        .monospacedDigit()
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.black.opacity(0.55))
                            .clipShape(Capsule())

                            // Progress bar
                            if let p = progress {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(.white.opacity(0.2))
                                        Capsule()
                                            .fill(timerColor)
                                            .frame(width: geo.size.width * p)
                                    }
                                }
                                .frame(width: 140, height: 4)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.top, 20)

                Spacer()

                // Guide text
                if !isRecording {
                    Text("Slowly pan around the entire room")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(.black.opacity(0.5))
                        .clipShape(Capsule())
                        .transition(.opacity)
                }

                // Scan type + record button
                VStack(spacing: 20) {
                    Label(template.type.displayName, systemImage: template.type.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(.blue.opacity(0.85))
                        .clipShape(Capsule())

                    // Limit hint (shown before recording starts)
                    if !isRecording && !isUnlimited {
                        Text("Max \(timeString(maxSeconds)) · Upgrade for longer scans")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Button(action: toggleRecording) {
                        ZStack {
                            Circle()
                                .stroke(.white, lineWidth: 3)
                                .frame(width: 72, height: 72)
                            if isRecording {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.red)
                                    .frame(width: 28, height: 28)
                            } else {
                                Circle().fill(.red).frame(width: 58, height: 58)
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.15), value: isRecording)
                }
                .padding(.bottom, 48)
            }
        }
        .navigationBarHidden(true)
        .onAppear { camera.start() }
        .onDisappear {
            timer?.invalidate()
            camera.stop()
        }
        .alert("Video limit reached", isPresented: $showLimitWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your plan allows up to \(timeString(maxSeconds)) per scan. The recording was saved automatically. Upgrade to Pro for longer scans.")
        }
    }

    // MARK: - Recording

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mov")
        camera.startRecording(to: url) { result in
            switch result {
            case .success(let videoURL): onVideoRecorded(videoURL)
            case .failure(let err):      print("Recording failed: \(err)")
            }
        }
        isRecording    = true
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
            if !isUnlimited && elapsedSeconds >= maxSeconds {
                showLimitWarning = true
                stopRecording()
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        timer?.invalidate()
        timer = nil
        camera.stopRecording()
    }

    private func timeString(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}
