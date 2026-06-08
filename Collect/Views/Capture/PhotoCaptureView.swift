import SwiftUI
import PhotosUI
import AVFoundation

/// Lets the user assemble one or more photos — taken with the camera or picked
/// from their library — to feed into the same AI scan pipeline as a video.
struct PhotoCaptureView: View {
    let template: PromptTemplate
    let onPhotosSelected: ([UIImage]) -> Void
    /// Save the photos now and analyze later (creates a draft).
    let onSaveDraft: ([UIImage]) -> Void

    /// AIService caps analysis at 20 frames, so there's no point collecting more.
    private static let maxPhotos = 20

    @State private var images: [UIImage] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var isLoading = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    private var remainingSlots: Int { max(0, Self.maxPhotos - images.count) }
    private var isFull: Bool { remainingSlots == 0 }

    var body: some View {
        VStack(spacing: 0) {
            if images.isEmpty {
                emptyState
            } else {
                photoGrid
            }

            sourceBar
        }
        .navigationTitle("Add Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onPhotosSelected(images)
                } label: {
                    Text(images.isEmpty ? "Analyze" : "Analyze \(images.count)")
                        .fontWeight(.semibold)
                }
                .disabled(images.isEmpty || isLoading)
            }
        }
        .onChange(of: pickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await loadPicked(newItems) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            MultiPhotoCameraView(remaining: remainingSlots) { captured in
                images.append(contentsOf: captured.prefix(remainingSlots))
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.blue.gradient)
            VStack(spacing: 6) {
                Text("Add Photos of Your Items")
                    .font(.title3.bold())
                Text("Take photos or choose from your library. AI will identify the items in them.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Label(template.type.displayName, systemImage: template.type.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(.blue.opacity(0.85), in: Capsule())
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 110)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Button {
                            images.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white, .black.opacity(0.55))
                                .padding(4)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var sourceBar: some View {
        VStack(spacing: 10) {
            if isLoading {
                ProgressView().padding(.bottom, 2)
            }
            HStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .disabled(isFull)

                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: remainingSlots,
                    matching: .images
                ) {
                    Label("Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .disabled(isFull)
            }

            if !images.isEmpty {
                Button {
                    onSaveDraft(images)
                } label: {
                    Label("Save as Draft — Analyze Later", systemImage: "tray.and.arrow.down")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .disabled(isLoading)
            }

            Text(isFull
                 ? "Maximum \(Self.maxPhotos) photos reached."
                 : "\(images.count) of \(Self.maxPhotos) photos")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }

    // MARK: - Loading

    private func loadPicked(_ items: [PhotosPickerItem]) async {
        isLoading = true
        for item in items {
            guard images.count < Self.maxPhotos else { break }
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        pickerItems = []
        isLoading = false
    }
}

// MARK: - Continuous camera

/// Full-screen camera that stays open so the user can snap several photos in a row,
/// see a running thumbnail strip, then tap Done to hand them all back at once.
private struct MultiPhotoCameraView: View {
    /// How many more photos the parent can still accept.
    let remaining: Int
    let onDone: ([UIImage]) -> Void

    @StateObject private var camera = PhotoCameraController()
    @State private var captured: [UIImage] = []
    @Environment(\.dismiss) private var dismiss

    private var isFull: Bool { captured.count >= remaining }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: camera.session).ignoresSafeArea()

            VStack {
                // Top bar: cancel / count / done
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                    Spacer()
                    if !captured.isEmpty {
                        Text("\(captured.count) added")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(.black.opacity(0.5), in: Capsule())
                    }
                    Spacer()
                    Button("Done") {
                        onDone(captured)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .disabled(captured.isEmpty)
                }
                .padding()

                Spacer()

                // Running thumbnail strip
                if !captured.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(captured.enumerated()), id: \.offset) { _, img in
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(.white.opacity(0.6), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 64)
                }

                // Shutter
                Group {
                    if isFull {
                        Text("Maximum reached — tap Done")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.vertical, 26)
                    } else {
                        Button(action: snap) {
                            ZStack {
                                Circle().stroke(.white, lineWidth: 4).frame(width: 74, height: 74)
                                Circle().fill(.white).frame(width: 60, height: 60)
                            }
                        }
                    }
                }
                .padding(.bottom, 36)
                .padding(.top, 12)
            }
        }
        .statusBarHidden()
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }

    private func snap() {
        guard !isFull else { return }
        camera.capture { image in
            if captured.count < remaining { captured.append(image) }
        }
    }
}

/// AVFoundation still-photo controller for `MultiPhotoCameraView`.
@MainActor
private final class PhotoCameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var onCapture: ((UIImage) -> Void)?

    func start() {
        Task.detached { [weak self] in
            await self?.setupSession()
        }
    }

    private func setupSession() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()
        session.startRunning()
    }

    func stop() {
        Task.detached { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func capture(onCapture: @escaping (UIImage) -> Void) {
        self.onCapture = onCapture
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        Task { @MainActor in
            self.onCapture?(image)
            self.onCapture = nil
        }
    }
}
