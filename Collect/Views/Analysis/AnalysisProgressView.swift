import SwiftUI

struct AnalysisProgressView: View {
    let room: Room
    let template: PromptTemplate
    let videoURL: URL
    let onCompleted: (ScanResult) -> Void
    let onFailed: (String) -> Void

    @State private var vm = AnalysisViewModel()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: phaseIcon)
                .font(.system(size: 72))
                .foregroundStyle(phaseColor)
                .symbolEffect(.pulse, isActive: !vm.isDone)
                .contentTransition(.symbolEffect(.replace))

            VStack(spacing: 10) {
                Text(phaseTitle)
                    .font(.title2.bold())

                Text(phaseSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if case .failed(let message) = vm.phase {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button("Try Again") {
                    Task { await runAnalysis() }
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .navigationTitle("Analyzing")
        .navigationBarBackButtonHidden(true)
        .task { await runAnalysis() }
    }

    private func runAnalysis() async {
        await vm.analyze(videoURL: videoURL, template: template)
        switch vm.phase {
        case .completed(let result): onCompleted(result)
        case .failed(let msg): onFailed(msg)
        default: break
        }
    }

    // MARK: - Phase display

    private var phaseIcon: String {
        switch vm.phase {
        case .idle, .extractingFrames: "film.stack"
        case .analyzing: "cpu"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var phaseColor: Color {
        switch vm.phase {
        case .completed: .green
        case .failed: .red
        default: .blue
        }
    }

    private var phaseTitle: String {
        switch vm.phase {
        case .idle: "Preparing…"
        case .extractingFrames: "Extracting Frames"
        case .analyzing(let n): "Analyzing \(n) Frames"
        case .completed(let r): "Found \(r.assets.count) Items"
        case .failed: "Analysis Failed"
        }
    }

    private var phaseSubtitle: String {
        switch vm.phase {
        case .idle: "Getting ready"
        case .extractingFrames: "Pulling key frames from your video"
        case .analyzing: "AI is identifying assets in the room…"
        case .completed: "Tap Save to keep the results"
        case .failed: "Something went wrong"
        }
    }
}
