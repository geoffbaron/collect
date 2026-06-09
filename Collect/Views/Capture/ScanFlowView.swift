import SwiftUI
import SwiftData

/// How the user supplies imagery for a scan.
enum CaptureMode {
    case video
    case photos
}

/// Hosts the entire scan flow in one NavigationStack inside a sheet.
/// Steps: PromptSelection → (optional) RoomLayout scan → Capture (video or photos) → AnalysisProgress → Results
struct ScanFlowView: View {
    let room: Room
    @Binding var isPresented: Bool
    /// Set when this scan is part of an inspection — tagged on the resulting Collection.
    let inspectionID: UUID?
    @EnvironmentObject private var limitsService: LimitsService
    @Environment(\.modelContext) private var modelContext

    /// How the flow begins.
    enum Entry {
        /// Normal scan: pick a scan type and video/photos capture mode.
        case full
        /// Quick "Add Item": jump straight to photo capture with a single-item prompt.
        case quickPhoto
        /// Analyze a previously saved draft (its held photos, skipping capture).
        case analyzeDraft(Collection)
    }

    enum Step {
        case promptSelection
        case capture(PromptTemplate, RoomLayout?, CaptureMode)
        case analysis(PromptTemplate, ScanSource, RoomLayout?)
        case groupReview(PromptTemplate, ScanResult, ScanSource, RoomLayout?)
        case results(PromptTemplate, ScanResult, ScanSource, RoomLayout?)
    }

    @State private var step: Step
    @State private var showLayoutScan = false
    @State private var capturedLayout: RoomLayout?
    @State private var pendingTemplate: PromptTemplate?
    @State private var pendingMode: CaptureMode = .video

    /// Set when analyzing a draft — ResultsView fills this collection instead of
    /// creating a new one.
    private let draftCollection: Collection?

    init(room: Room, isPresented: Binding<Bool>, entry: Entry = .full, inspectionID: UUID? = nil) {
        self.room = room
        self._isPresented = isPresented
        self.inspectionID = inspectionID
        switch entry {
        case .full:
            self.draftCollection = nil
            self._step = State(initialValue: .promptSelection)
        case .quickPhoto:
            self.draftCollection = nil
            let template = PromptManager.template(for: .singleItem)
            let layout = room.layoutData.flatMap { RoomLayout.from($0) }
            self._step = State(initialValue: .capture(template, layout, .photos))
        case .analyzeDraft(let draft):
            self.draftCollection = draft
            let layout = room.layoutData.flatMap { RoomLayout.from($0) }
            let source = DraftStorage.source(for: draft)
            self._step = State(initialValue: .analysis(draft.template, source, layout))
        }
    }

    var body: some View {
        NavigationStack {
            currentView
                .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(isPresented: $showLayoutScan) {
            RoomScanSheet(roomName: room.name) { layout in
                capturedLayout = layout
                if let template = pendingTemplate {
                    step = .capture(template, layout, pendingMode)
                }
                pendingTemplate = nil
            } onCancel: {
                // User skipped layout scan — proceed to capture without layout
                if let template = pendingTemplate {
                    step = .capture(template, capturedLayout, pendingMode)
                }
                pendingTemplate = nil
            }
        }
    }

    @ViewBuilder
    private var currentView: some View {
        switch step {
        case .promptSelection:
            PromptSelectionView(room: room) { template, includeLayout, mode in
                if includeLayout {
                    pendingTemplate = template
                    pendingMode = mode
                    showLayoutScan = true
                } else {
                    // Use existing room layout (or nil) without rescanning
                    let existing = room.layoutData.flatMap { RoomLayout.from($0) }
                    step = .capture(template, existing, mode)
                }
            } onCancel: {
                isPresented = false
            }

        case .capture(let template, let layout, let mode):
            switch mode {
            case .video:
                VideoCaptureView(room: room, template: template) { videoURL in
                    step = .analysis(template, .video(videoURL), layout)
                } onSaveDraft: { videoURL in
                    saveVideoDraft(template: template, videoURL: videoURL)
                }
            case .photos:
                PhotoCaptureView(template: template) { images in
                    step = .analysis(template, .photos(images), layout)
                } onSaveDraft: { images in
                    saveDraft(template: template, images: images)
                }
            }

        case .analysis(let template, let source, let layout):
            AnalysisProgressView(
                room: room,
                template: template,
                source: source
            ) { scanResult in
                // Route through group review if AI flagged possible duplicates
                if scanResult.possibleDuplicateGroups.isEmpty {
                    step = .results(template, scanResult, source, layout)
                } else {
                    step = .groupReview(template, scanResult, source, layout)
                }
            } onFailed: { _ in
                // Stay on analysis screen — it shows a retry button
            }

        case .groupReview(let template, let scanResult, let source, let layout):
            GroupReviewView(scanResult: scanResult) { resolvedAssets in
                // Build a new ScanResult with the user's grouping decisions applied
                let resolved = ScanResult(assets: resolvedAssets, selectedFrames: scanResult.selectedFrames)
                step = .results(template, resolved, source, layout)
            }

        case .results(let template, let scanResult, let source, let layout):
            ResultsView(
                room: room,
                template: template,
                scanResult: scanResult,
                source: source,
                capturedLayout: layout,
                existingCollection: draftCollection,
                inspectionID: inspectionID
            ) {
                Task { await limitsService.refreshUsage() }
                isPresented = false
            }
        }
    }

    // MARK: - Draft

    /// Save the captured photos as a draft to analyze later. Drafts are local-only
    /// (not synced) and don't count against the scan quota until analyzed.
    private func saveDraft(template: PromptTemplate, images: [UIImage]) {
        let collection = makeDraftCollection(template: template)
        collection.pendingPhotos = images.compactMap {
            $0.downscaled(maxDimension: 768).jpegData(compressionQuality: 0.6)
        }
        modelContext.insert(collection)
        try? modelContext.save()
        isPresented = false
    }

    /// Save a recorded video as a draft — move the temp file into the persistent
    /// drafts folder and reference it by filename.
    private func saveVideoDraft(template: PromptTemplate, videoURL: URL) {
        let collection = makeDraftCollection(template: template)
        if let fileName = DraftStorage.persist(videoURL: videoURL) {
            collection.videoFileName = fileName
        }
        modelContext.insert(collection)
        try? modelContext.save()
        isPresented = false
    }

    private func makeDraftCollection(template: PromptTemplate) -> Collection {
        let collection = Collection(
            promptType: template.type,
            room: room,
            customPrompt: template.type == .custom ? template.userPromptPrefix : nil
        )
        collection.status = .draft
        return collection
    }
}

// MARK: - Draft file storage

/// Manages persistent storage for video drafts (photo drafts live inline on the
/// Collection). Files live in Documents/Drafts so they survive app relaunches.
enum DraftStorage {
    static var directory: URL {
        let dir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Drafts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func videoURL(fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    /// Move a temp recording into the drafts folder; returns the stored filename.
    static func persist(videoURL tempURL: URL) -> String? {
        let fileName = UUID().uuidString + ".mov"
        let dest = videoURL(fileName: fileName)
        do {
            try FileManager.default.moveItem(at: tempURL, to: dest)
            return fileName
        } catch {
            // Fall back to copy if move fails (e.g. cross-volume)
            try? FileManager.default.copyItem(at: tempURL, to: dest)
            return FileManager.default.fileExists(atPath: dest.path) ? fileName : nil
        }
    }

    static func removeVideo(fileName: String?) {
        guard let fileName else { return }
        try? FileManager.default.removeItem(at: videoURL(fileName: fileName))
    }

    /// Reconstruct the analysis source for a draft — video file if present, else
    /// the inline photos.
    static func source(for draft: Collection) -> ScanSource {
        if let fileName = draft.videoFileName {
            let url = videoURL(fileName: fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                return .video(url)
            }
        }
        let images = (draft.pendingPhotos ?? []).compactMap { UIImage(data: $0) }
        return .photos(images)
    }
}
