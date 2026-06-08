import Foundation
import Observation
import UIKit

/// Where the frames to analyze come from. Video is extracted into frames first;
/// photos are already frames and skip extraction.
enum ScanSource {
    case video(URL)
    case photos([UIImage])
}

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

    func analyze(source: ScanSource, template: PromptTemplate) async {
        do {
            let frames: [UIImage]
            switch source {
            case .video(let url):
                phase = .extractingFrames
                frames = try await FrameExtractor.shared.extractFrames(from: url)
            case .photos(let images):
                frames = images
            }
            guard !frames.isEmpty else {
                switch source {
                case .video:  phase = .failed("Could not extract frames from video. Try recording again.")
                case .photos: phase = .failed("No usable photos. Try adding photos again.")
                }
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
