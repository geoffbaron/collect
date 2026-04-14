import SwiftUI
import SwiftData

struct RoomDetailView: View {
    @Bindable var room: Room
    @EnvironmentObject private var featuresService: FeaturesService
    @EnvironmentObject private var limitsService: LimitsService
    @Environment(\.modelContext) private var modelContext
    @State private var showScan = false
    @State private var showRoomScan = false
    @State private var showFloorPlan = false
    @Query private var allCollections: [Collection]

    // Filter to only this room's collections, sorted newest first
    private var collections: [Collection] {
        allCollections
            .filter { $0.room?.id == room.id }
            .sorted { $0.capturedAt > $1.capturedAt }
    }

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

                    if featuresService.floorScansEnabled {
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
                    if featuresService.floorScansEnabled {
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
                    }

                    // Past scans
                    if !collections.isEmpty {
                        Section("Past Scans") {
                            ForEach(collections) { collection in
                                NavigationLink(value: collection) {
                                    CollectionRow(collection: collection)
                                }
                            }
                            .onDelete(perform: deleteCollections)
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
        .sheet(isPresented: $showRoomScan) {
            if featuresService.floorScansEnabled {
                RoomScanSheet(roomName: room.name) { layout in
                    room.layoutData = layout.toData()
                }
            }
        }
    }

    private func deleteCollections(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(collections[index])
        }
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
        }
    }

    private var color: Color {
        switch status {
        case .recording, .failed: .red
        case .extractingFrames, .analyzing: .orange
        case .completed: .green
        }
    }
}
