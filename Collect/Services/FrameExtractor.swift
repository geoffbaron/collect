import AVFoundation
import UIKit

actor FrameExtractor {
    static let shared = FrameExtractor()

    func extractFrames(from url: URL, targetFPS: Double = 1.0, maxFrames: Int = 30) async throws -> [UIImage] {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        guard seconds > 0 else { return [] }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 768, height: 768)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.25, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter  = CMTime(seconds: 0.25, preferredTimescale: 600)

        // Build timestamps at targetFPS, capped at maxFrames
        let step = max(1.0 / targetFPS, seconds / Double(maxFrames))
        var times: [CMTime] = []
        var t = 0.0
        while t < seconds && times.count < maxFrames {
            times.append(CMTime(seconds: t, preferredTimescale: 600))
            t += step
        }

        var frames: [UIImage] = []
        var lastFrame: UIImage?

        for time in times {
            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else { continue }
            let image = UIImage(cgImage: cgImage)
            if let last = lastFrame, isDuplicate(image, last) { continue }
            frames.append(image)
            lastFrame = image
        }

        return frames
    }

    // Compare 8×8 pixel thumbnails — fast perceptual similarity check
    private func isDuplicate(_ a: UIImage, _ b: UIImage) -> Bool {
        guard let aBytes = thumbnail(a), let bBytes = thumbnail(b) else { return false }
        let diff = zip(aBytes, bBytes).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
        return Double(diff) / Double(aBytes.count) < 10.0
    }

    private func thumbnail(_ image: UIImage) -> [UInt8]? {
        let size = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        let small = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let cgImage = small.cgImage,
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data else { return nil }
        let ptr = CFDataGetBytePtr(data)
        let len = CFDataGetLength(data)
        return Array(UnsafeBufferPointer(start: ptr, count: len))
    }
}
