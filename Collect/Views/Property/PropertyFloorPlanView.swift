import SwiftUI

struct PropertyFloorPlanView: View {
    let property: Property

    private struct RoomEntry: Identifiable {
        let id: UUID
        let room: Room
        let layout: RoomLayout
        let assets: [Asset]
    }

    private var scannedRooms: [RoomEntry] {
        property.sortedFloors.flatMap { floor in
            floor.sortedRooms.compactMap { room in
                guard let data = room.layoutData,
                      let layout = RoomLayout.from(data) else { return nil }
                let assets = room.collections.flatMap { $0.assets }
                return RoomEntry(id: room.id, room: room, layout: layout, assets: assets)
            }
        }
    }

    @State private var selectedEntry: RoomEntry?

    var body: some View {
        Group {
            if scannedRooms.isEmpty {
                ContentUnavailableView {
                    Label("No Room Layouts", systemImage: "map")
                } description: {
                    Text("Scan room layouts from each room's detail screen to build your floor plan.")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(scannedRooms) { entry in
                            Button {
                                selectedEntry = entry
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    FloorPlanView(layout: entry.layout, assets: entry.assets, showLegend: false)
                                        .frame(height: 160)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                        )

                                    HStack {
                                        Text(entry.room.name)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        if !entry.assets.filter({ $0.hasPinnedPosition }).isEmpty {
                                            let count = entry.assets.filter({ $0.hasPinnedPosition }).count
                                            Text("· \(count) pinned")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                        }
                                    }

                                    if let floor = entry.room.floor {
                                        Text(floor.name)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Floor Plans")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedEntry) { entry in
            NavigationStack {
                FloorPlanView(layout: entry.layout, assets: entry.assets, showLegend: true)
                    .navigationTitle(entry.layout.roomName)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Done") { selectedEntry = nil }
                        }
                    }
            }
        }
    }
}

extension RoomLayout: Identifiable {
    var id: String { roomName + scannedAt.description }
}
