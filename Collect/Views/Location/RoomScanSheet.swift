import SwiftUI
import UIKit
import RoomPlan

// MARK: - SwiftUI wrapper

struct RoomScanSheet: UIViewControllerRepresentable {
    var roomName: String
    var onComplete: (RoomLayout) -> Void
    var onCancel: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> RoomScanViewController {
        let vc = RoomScanViewController()
        vc.roomName = roomName
        vc.onComplete = onComplete
        vc.onCancel = onCancel
        return vc
    }

    func updateUIViewController(_ uiViewController: RoomScanViewController, context: Context) {}
}

// MARK: - UIViewController

final class RoomScanViewController: UIViewController {

    var roomName: String = "Room"
    var onComplete: ((RoomLayout) -> Void)?
    var onCancel: (() -> Void)?

    private var captureView: RoomCaptureView!
    private var doneButton: UIButton!
    private var processing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCapture()
        setupOverlay()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let config = RoomCaptureSession.Configuration()
        captureView.captureSession.run(configuration: config)
    }

    private func setupCapture() {
        captureView = RoomCaptureView(frame: view.bounds)
        captureView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        captureView.captureSession.delegate = self
        view.addSubview(captureView)
    }

    private func setupOverlay() {
        // Cancel
        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("Cancel", for: .normal)
        cancelBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        cancelBtn.setTitleColor(.white, for: .normal)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cancelBtn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancelBtn)

        // Done
        var cfg = UIButton.Configuration.filled()
        cfg.title = "Done Scanning"
        cfg.baseForegroundColor = .white
        cfg.baseBackgroundColor = .systemBlue
        cfg.cornerStyle = .large
        cfg.buttonSize = .large
        doneButton = UIButton(configuration: cfg)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        view.addSubview(doneButton)

        NSLayoutConstraint.activate([
            cancelBtn.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            cancelBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            doneButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            doneButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            doneButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
        ])
    }

    @objc private func doneTapped() {
        guard !processing else { return }
        processing = true
        doneButton.isEnabled = false
        var c = doneButton.configuration
        c?.showsActivityIndicator = true
        c?.title = "Processing…"
        doneButton.configuration = c
        captureView.captureSession.stop()
    }

    @objc private func cancelTapped() {
        captureView.captureSession.stop()
        dismiss(animated: true) { [weak self] in
            self?.onCancel?()
        }
    }
}

// MARK: - Session Delegate

extension RoomScanViewController: RoomCaptureSessionDelegate {

    func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        guard error == nil else {
            DispatchQueue.main.async { self.dismiss(animated: true) }
            return
        }
        Task {
            do {
                let builder = RoomBuilder(options: [.beautifyObjects])
                let room = try await builder.capturedRoom(from: data)
                let layout = Self.makeLayout(from: room, name: roomName)
                await MainActor.run {
                    onComplete?(layout)
                    dismiss(animated: true)
                }
            } catch {
                await MainActor.run { dismiss(animated: true) }
            }
        }
    }

    static func makeLayout(from room: CapturedRoom, name: String) -> RoomLayout {
        var walls: [RoomLayout.Wall] = []
        var openings: [RoomLayout.Opening] = []
        var objects: [RoomLayout.PlacedObject] = []

        for s in room.walls {
            let p = s.transform.columns.3
            let r = s.transform.columns.0
            walls.append(.init(width: s.dimensions.x, height: s.dimensions.y,
                               centerX: p.x, centerZ: p.z, yaw: atan2(r.z, r.x)))
        }

        func addOpening(_ s: CapturedRoom.Surface, kind: RoomLayout.Opening.Kind) {
            let p = s.transform.columns.3
            let r = s.transform.columns.0
            openings.append(.init(kind: kind, width: s.dimensions.x,
                                  centerX: p.x, centerZ: p.z, yaw: atan2(r.z, r.x)))
        }
        room.doors.forEach    { addOpening($0, kind: .door)    }
        room.windows.forEach  { addOpening($0, kind: .window)  }
        room.openings.forEach { addOpening($0, kind: .opening) }

        for obj in room.objects {
            let p = obj.transform.columns.3
            let r = obj.transform.columns.0
            objects.append(.init(category: categoryName(obj.category),
                                 width: obj.dimensions.x, depth: obj.dimensions.z,
                                 centerX: p.x, centerZ: p.z, yaw: atan2(r.z, r.x)))
        }

        return RoomLayout(roomName: name, scannedAt: Date(),
                         walls: walls, openings: openings, objects: objects)
    }

    private static func categoryName(_ cat: CapturedRoom.Object.Category) -> String {
        // iOS 16 categories (struct with static properties, use == comparison)
        if cat == .sofa          { return "sofa" }
        if cat == .chair         { return "chair" }
        if cat == .table         { return "table" }
        if cat == .bed           { return "bed" }
        if cat == .television    { return "television" }
        if cat == .refrigerator  { return "refrigerator" }
        if cat == .toilet        { return "toilet" }
        if cat == .bathtub       { return "bathtub" }
        if cat == .sink          { return "sink" }
        if cat == .storage       { return "storage" }
        if cat == .stove         { return "stove" }
        if cat == .fireplace     { return "fireplace" }
        if cat == .dishwasher    { return "dishwasher" }
        if cat == .stairs        { return "stairs" }
        if cat == .washerDryer   { return "washerDryer" }
        return "object"
    }
}
