import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class AnalysisViewModel {

    enum Phase {
        case idle
        case extractingFrames
        case analyzing(frameCount: Int)
        case completed(ScanResult)
        case failed(String)
    }

    var phase: Phase = .idle

    var isDone: Bool {
        switch phase {
        case .completed, .failed: true
        default: false
        }
    }

    func analyze(videoURL: URL, template: PromptTemplate) async {
        phase = .extractingFrames
        do {
            let frames = try await FrameExtractor.shared.extractFrames(from: videoURL)
            guard !frames.isEmpty else {
                phase = .failed("Could not extract frames from video. Try recording again.")
                return
            }

            phase = .analyzing(frameCount: frames.count)
            let result = try await AIService.shared.analyzeScan(frames, template: template)

            if result.assets.isEmpty {
                phase = .failed("No items were identified. Try a different scan type or re-record.")
            } else {
                phase = .completed(result)
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
