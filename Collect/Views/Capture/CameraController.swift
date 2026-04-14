import AVFoundation
import UIKit

@MainActor
final class CameraController: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var completion: ((Result<URL, Error>) -> Void)?

    func start() {
        Task.detached { [weak self] in
            await self?.setupSession()
        }
    }

    private func setupSession() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else { return }

        session.beginConfiguration()
        session.sessionPreset = .high

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }

        if let audio = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audio),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()
        session.startRunning()
    }

    func stop() {
        Task.detached { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func startRecording(to url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        self.completion = completion
        movieOutput.startRecording(to: url, recordingDelegate: self)
    }

    func stopRecording() {
        movieOutput.stopRecording()
    }

    // MARK: - AVCaptureFileOutputRecordingDelegate

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo url: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                self.completion?(.failure(error))
            } else {
                self.completion?(.success(url))
            }
            self.completion = nil
        }
    }
}
