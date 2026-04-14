import SwiftUI
import AVFoundation

struct VideoCaptureView: View {
    let room: Room
    let template: PromptTemplate
    let onVideoRecorded: (URL) -> Void

    @StateObject private var camera = CameraController()
    @State private var isRecording = false
    @State private var elapsedSeconds = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                // Timer badge (visible during recording)
                HStack {
                    Spacer()
                    if isRecording {
                        HStack(spacing: 6) {
                            Circle().fill(.red).frame(width: 8, height: 8)
                            Text(timeString(elapsedSeconds))
                                .foregroundStyle(.white)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.black.opacity(0.55))
                        .clipShape(Capsule())
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

                // Scan type label + record button
                VStack(spacing: 20) {
                    Label(template.type.displayName, systemImage: template.type.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(.blue.opacity(0.85))
                        .clipShape(Capsule())

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
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mov")
        camera.startRecording(to: url) { result in
            switch result {
            case .success(let videoURL): onVideoRecorded(videoURL)
            case .failure(let err): print("Recording failed: \(err)")
            }
        }
        isRecording = true
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
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
