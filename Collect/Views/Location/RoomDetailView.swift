import SwiftUI
import SwiftData
import ARKit

struct RoomDetailView: View {
    @Bindable var room: Room
    @EnvironmentObject private var featuresService: FeaturesService
    @EnvironmentObject private var limitsService: LimitsService
    @EnvironmentObject private var syncService: SyncService
    @Environment(\.modelContext) private var modelContext
    @State private var showScan = false
    @State private var showAddItem = false
    @State private var showRoomScan = false
    @State private var showFloorPlan = false
    @State private var draftToAnalyze: Collection?
    @State private var showBatchAnalyze = false
    @Query private var allCollections: [Collection]

    private var lidarAvailable: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    // Filter to only this room's collections, sorted newest first
    private var collections: [Collection] {
        allCollections
            .filter { $0.room?.id == room.id }
            .sorted { $0.capturedAt > $1.capturedAt }
    }

    private var drafts: [Collection] { collections.filter { $0.isDraft } }
    private var scans:  [Collection] { collections.filter { !$0.isDraft } }

    var body: some View {
        Group {
            if collections.isEmpty && !room.hasLayout {
                ContentUnavailableView {
                    Label("No Scans Yet", systemImage: "camera.viewfinder")
                } description: {
                    Text("Scan this room to start collecting assets with AI.")
                } actions: {
                    Button {
                        showScan = true
                    } label: {
                        Label("Scan Room", systemImage: "camera.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showAddItem = true
                    } label: {
                        Label("Add Item", systemImage: "photo.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!limitsService.canScan)

                    if lidarAvailable {
                        Button {
                            showRoomScan = true
                        } label: {
                            Label("Scan Room Layout", systemImage: "map")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                List {
                    // Layout section (floor_scans flag)
                    if lidarAvailable {
                        Section {
                            if room.hasLayout, let data = room.layoutData, let layout = RoomLayout.from(data) {
                                let roomAssets = collections.flatMap { $0.assets }
                                let unpinnedCount = roomAssets.filter { !$0.hasPinnedPosition }.count
                                NavigationLink {
                                    FloorPlanView(layout: layout, assets: roomAssets)
                                        .navigationTitle("Floor Plan")
                                        .navigationBarTitleDisplayMode(.inline)
                                } label: {
                                    HStack {
                                        Label("View Floor Plan", systemImage: "map.fill")
                                            .foregroundStyle(.blue)
                                        Spacer()
                                        if unpinnedCount > 0 {
                                            Text("\(unpinnedCount) unpinned")
                                                .font(.caption)
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 8).padding(.vertical, 3)
                                                .background(.orange, in: Capsule())
                                        }
                                    }
                                }
                                Button {
                                    showRoomScan = true
                                } label: {
                                    Label("Rescan Layout", systemImage: "arrow.triangle.2.circlepath")
                                        .foregroundStyle(.secondary)
                                        .font(.subheadline)
                                }
                            } else {
                                Button {
                                    showRoomScan = true
                                } label: {
                                    Label("Scan Room Layout", systemImage: "map")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }

                    // Asset scan section
                    Section {
                        Button {
                            showScan = true
                        } label: {
                            Label("New Scan", systemImage: "camera.fill")
                        }
                        Button {
                            showAddItem = true
                        } label: {
                            Label("Add Item", systemImage: "photo.badge.plus")
                        }
                        .disabled(!limitsService.canScan)

                        if room.totalAssets > 0 {
                            NavigationLink {
                                RoomItemsView(room: room)
                            } label: {
                                Label("View All Items (\(room.totalAssets))", systemImage: "square.grid.2x2")
                            }
                        }
                    }

                    // Drafts awaiting analysis
                    if !drafts.isEmpty {
                        Section {
                            ForEach(drafts) { draft in
                                Button {
                                    draftToAnalyze = draft
                                } label: {
                                    DraftRow(draft: draft)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete(perform: deleteDrafts)

                            if drafts.count > 1 {
                                Button {
                                    showBatchAnalyze = true
                                } label: {
                                    Label("Analyze All (\(drafts.count))", systemImage: "sparkles")
                                }
                                .disabled(!limitsService.canScan)
                            }
                        } header: {
                            Text("Drafts — Tap to Analyze")
                        } footer: {
                            Text("Photos and videos saved for later. Analyze when you're at your desk or on better Wi-Fi.")
                        }
                    }

                    // Past scans
                    if !scans.isEmpty {
                        Section("Past Scans") {
                            ForEach(scans) { collection in
                                NavigationLink(value: collection) {
                                    CollectionRow(collection: collection)
                                }
                            }
                            .onDelete(perform: deleteScans)
                        }
                    }

                    // Total
                    let totalAssets = collections.reduce(0) { $0 + $1.assets.count }
                    if totalAssets > 0 {
                        Section {
                            HStack {
                                Text("Total Assets Collected")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(totalAssets)")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(room.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showScan = true
                } label: {
                    Image(systemName: limitsService.canScan ? "camera.fill" : "lock.fill")
                }
                .disabled(!limitsService.canScan)
            }
        }
        .sheet(isPresented: $showScan) {
            ScanFlowView(room: room, isPresented: $showScan)
        }
        .sheet(isPresented: $showAddItem) {
            ScanFlowView(room: room, isPresented: $showAddItem, entry: .quickPhoto)
        }
        .sheet(item: $draftToAnalyze) { draft in
            ScanFlowView(
                room: room,
                isPresented: Binding(get: { draftToAnalyze != nil },
                                     set: { if !$0 { draftToAnalyze = nil } }),
                entry: .analyzeDraft(draft)
            )
        }
        .sheet(isPresented: $showBatchAnalyze) {
            BatchAnalyzeView(drafts: drafts, room: room, isPresented: $showBatchAnalyze)
        }
        .sheet(isPresented: $showRoomScan) {
            if lidarAvailable {
                RoomScanSheet(roomName: room.name) { layout in
                    room.layoutData = layout.toData()
                    // Room metadata (map position) syncs; layout binary stays local-only
                    syncService.enqueue(.upsertRoom(id: room.id))
                }
            }
        }
    }

    private func deleteScans(at offsets: IndexSet) {
        for index in offsets {
            let collection = scans[index]
            syncService.enqueue(.softDeleteCollection(id: collection.id))
            modelContext.delete(collection)
        }
    }

    private func deleteDrafts(at offsets: IndexSet) {
        // Drafts are local-only — nothing to soft-delete in the cloud. Remove any
        // backing video file too so it doesn't leak on disk.
        for index in offsets {
            let draft = drafts[index]
            DraftStorage.removeVideo(fileName: draft.videoFileName)
            modelContext.delete(draft)
        }
    }
}

// MARK: - Draft row

struct DraftRow: View {
    let draft: Collection

    var body: some View {
        HStack(spacing: 12) {
            if let data = draft.pendingPhotos?.first, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 48, height: 48)
                    .overlay { Image(systemName: "photo.stack").foregroundStyle(.tertiary) }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(draft.prompt.displayName)
                    .font(.headline)
                HStack(spacing: 6) {
                    StatusBadge(status: .draft)
                    let n = draft.pendingPhotos?.count ?? 0
                    Text("\(n) photo\(n == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("· \(draft.capturedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

// MARK: - Batch draft analysis

/// Analyzes a room's drafts one at a time. Sequential by design: each draft is a
/// separate bounded LLM call (≤20 frames, 768px), so processing serially keeps a
/// large pile of drafts from flooding the pipeline. Stops cleanly at the quota.
@MainActor
@Observable
final class BatchAnalyzeModel {
    enum Phase: Equatable {
        case running(done: Int, total: Int, current: String)
        case finished(succeeded: Int, failed: Int, quotaStopped: Bool)
    }

    var phase: Phase = .running(done: 0, total: 0, current: "")

    func run(drafts: [Collection], room: Room, modelContext: ModelContext, syncService: SyncService) async {
        let total = drafts.count
        var succeeded = 0
        var failed = 0
        var quotaStopped = false
        let layout = room.layoutData.flatMap { RoomLayout.from($0) }

        for (i, draft) in drafts.enumerated() {
            if Task.isCancelled { break }
            phase = .running(done: i, total: total, current: draft.prompt.displayName)

            let videoFile = draft.videoFileName   // capture before persist clears it
            do {
                let frames: [UIImage]
                switch DraftStorage.source(for: draft) {
                case .video(let url):   frames = try await FrameExtractor.shared.extractFrames(from: url)
                case .photos(let imgs): frames = imgs
                }
                guard !frames.isEmpty else { failed += 1; continue }

                let result = try await AIService.shared.analyzeScan(frames, template: draft.template)
                persist(result, into: draft, layout: layout, modelContext: modelContext, syncService: syncService)
                DraftStorage.removeVideo(fileName: videoFile)
                succeeded += 1
            } catch let error as AIServiceError {
                // Quota or auth issues won't resolve for later drafts — stop now and
                // leave the rest as drafts.
                switch error {
                case .httpError(429, _), .notAuthenticated: quotaStopped = true
                default: failed += 1
                }
                if quotaStopped { break }
            } catch {
                // A single bad draft shouldn't abort the batch — it stays a draft.
                failed += 1
            }
        }

        phase = .finished(succeeded: succeeded, failed: failed, quotaStopped: quotaStopped)
    }

    private func persist(
        _ result: ScanResult,
        into collection: Collection,
        layout: RoomLayout?,
        modelContext: ModelContext,
        syncService: SyncService
    ) {
        collection.status = .completed
        collection.pendingPhotos = nil
        collection.videoFileName = nil

        let frames = result.selectedFrames
        let positionMap = layout?.matchAssets(result.assets.map { (name: $0.name, category: $0.category) }) ?? [:]

        var ids: [UUID] = []
        for (idx, item) in result.assets.enumerated() {
            let asset = Asset(
                name: item.name,
                category: item.category,
                assetDescription: item.description,
                condition: item.condition,
                quantity: item.quantity,
                confidence: item.confidence,
                collection: collection
            )
            asset.isConfirmed = true
            asset.estimatedValue = item.estimatedValue
            if let placed = positionMap[idx] {
                asset.layoutX = placed.centerX
                asset.layoutZ = placed.centerZ
            }
            modelContext.insert(asset)
            if let i1 = item.frameIndices.first, i1 < frames.count {
                asset.photo1Data = frames[i1].jpegData(compressionQuality: 0.8)
            }
            if item.frameIndices.count > 1, item.frameIndices[1] < frames.count {
                asset.photo2Data = frames[item.frameIndices[1]].jpegData(compressionQuality: 0.8)
            }
            ids.append(asset.id)
        }

        try? modelContext.save()
        syncService.enqueue(.upsertCollection(id: collection.id))
        for id in ids { syncService.enqueue(.upsertAsset(id: id)) }
    }
}

struct BatchAnalyzeView: View {
    let drafts: [Collection]
    let room: Room
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var limitsService: LimitsService
    @State private var model = BatchAnalyzeModel()
    @State private var started = false

    private var isRunning: Bool {
        if case .running = model.phase { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Spacer()

                switch model.phase {
                case .running(let done, let total, let current):
                    Image(systemName: "sparkles")
                        .font(.system(size: 56))
                        .foregroundStyle(.purple)
                        .symbolEffect(.pulse)
                    Text("Analyzing \(min(done + 1, max(total, 1))) of \(total)…")
                        .font(.title3.bold())
                    Text(current)
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(done), total: Double(max(total, 1)))
                        .padding(.horizontal, 44)
                    Text("Processing one at a time to keep analysis reliable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                case .finished(let s, let f, let quota):
                    Image(systemName: quota ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(quota ? .orange : .green)
                    Text(quota ? "Stopped at Scan Limit" : "All Done")
                        .font(.title2.bold())
                    VStack(spacing: 6) {
                        if s > 0 { Text("\(s) analyzed").foregroundStyle(.green) }
                        if f > 0 { Text("\(f) couldn't be read — kept as drafts").foregroundStyle(.secondary) }
                        if quota {
                            Text("Monthly scan limit reached. The remaining drafts are untouched — analyze them after upgrading or next month.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }
                }

                Spacer()

                if case .finished = model.phase {
                    Button("Done") { isPresented = false }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
            .padding()
            .navigationTitle("Analyze Drafts")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isRunning)
            .toolbar {
                if isRunning {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Stop") { isPresented = false }
                    }
                }
            }
            .task {
                guard !started else { return }
                started = true
                await model.run(drafts: drafts, room: room, modelContext: modelContext, syncService: syncService)
                await limitsService.refreshUsage()
            }
        }
    }
}

// MARK: - All items in a room

/// A flat list of every item in a room, pooled across all of its scans, with a
/// search field and a running total value.
struct RoomItemsView: View {
    let room: Room
    @State private var query = ""

    private var allItems: [Asset] {
        room.collections
            .flatMap { $0.assets }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private var filtered: [Asset] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allItems }
        return allItems.filter {
            $0.name.lowercased().contains(q)
            || $0.category.lowercased().contains(q)
            || $0.assetDescription.lowercased().contains(q)
        }
    }

    private var totalValue: Double {
        allItems.reduce(0) { $0 + ($1.estimatedValue ?? 0) * Double($1.quantity) }
    }

    var body: some View {
        Group {
            if allItems.isEmpty {
                ContentUnavailableView {
                    Label("No Items", systemImage: "cube.box")
                } description: {
                    Text("Scan this room or add an item to start collecting.")
                }
            } else {
                List {
                    if totalValue > 0 {
                        Section {
                            HStack {
                                Text("Estimated Total Value")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(totalValue, format: .currency(code: "USD"))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    Section {
                        ForEach(filtered) { asset in
                            NavigationLink(value: asset) {
                                AssetRow(asset: asset)
                            }
                        }
                    } header: {
                        Text("\(filtered.count) Item\(filtered.count == 1 ? "" : "s")")
                            .textCase(nil)
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
        .navigationTitle("All Items")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search items in this room")
    }
}

struct CollectionRow: View {
    let collection: Collection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(collection.prompt.displayName, systemImage: collection.prompt.icon)
                    .font(.headline)
                Spacer()
                StatusBadge(status: collection.status)
            }

            HStack(spacing: 12) {
                Text(collection.capturedAt.formatted(date: .abbreviated, time: .shortened))
                if !collection.assets.isEmpty {
                    Text("· \(collection.assets.count) assets")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct StatusBadge: View {
    let status: CollectionStatus

    var body: some View {
        Text(label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case .recording: "Recording"
        case .extractingFrames: "Processing"
        case .analyzing: "Analyzing"
        case .completed: "Done"
        case .failed: "Failed"
        case .draft: "Draft"
        }
    }

    private var color: Color {
        switch status {
        case .recording, .failed: .red
        case .extractingFrames, .analyzing: .orange
        case .completed: .green
        case .draft: .purple
        }
    }
}
