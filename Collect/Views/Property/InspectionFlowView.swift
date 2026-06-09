import SwiftUI
import SwiftData

/// PM mode: walks a tech room-by-room through a unit inspection.
/// Each room gets scanned with the existing AI camera flow; the resulting
/// Collection is tagged with the inspection's ID.
struct InspectionFlowView: View {
    let inspection: PMInspection
    let unit: PMUnit
    let inspectionService: InspectionService

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allCollections: [Collection]
    @Query private var allRooms: [Room]

    @State private var selectedRoom: Room?
    @State private var showScan = false
    @State private var showAddRoom = false
    @State private var newRoomName = ""

    private var inspectionUUID: UUID? { UUID(uuidString: inspection.id) }

    private var unitUUID: UUID? { UUID(uuidString: unit.id) }

    /// Rooms that belong to this unit (have unitID set)
    private var unitRooms: [Room] {
        guard let uid = unitUUID else { return [] }
        return allRooms
            .filter { $0.unitID == uid }
            .sorted { $0.name < $1.name }
    }

    /// Collections tagged with this inspection
    private var inspectionCollections: [Collection] {
        guard let iid = inspectionUUID else { return [] }
        return allCollections.filter { $0.inspectionID == iid }
    }

    private var scannedRoomIDs: Set<UUID> {
        Set(inspectionCollections.compactMap { $0.room?.id })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Label(inspection.inspectionType.displayName, systemImage: inspection.inspectionType.systemImage)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(scannedRoomIDs.count)/\(unitRooms.count) rooms scanned")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Unit \(unit.unitNumber)")
                }

                Section {
                    if unitRooms.isEmpty {
                        Text("No rooms yet — add one below.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(unitRooms) { room in
                            RoomScanRow(
                                room: room,
                                isScanned: scannedRoomIDs.contains(room.id)
                            ) {
                                selectedRoom = room
                                showScan = true
                            }
                        }
                    }
                    Button {
                        showAddRoom = true
                    } label: {
                        Label("Add Room", systemImage: "plus.circle")
                            .foregroundStyle(.blue)
                    }
                } header: {
                    Text("Rooms")
                }
            }
            .navigationTitle("Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Complete") {
                        Task {
                            await inspectionService.complete(inspection)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(scannedRoomIDs.isEmpty)
                }
            }
            .sheet(isPresented: $showScan) {
                if let room = selectedRoom {
                    ScanFlowView(
                        room: room,
                        isPresented: $showScan,
                        inspectionID: inspectionUUID
                    )
                }
            }
            .alert("Add Room", isPresented: $showAddRoom) {
                TextField("Room Name", text: $newRoomName)
                Button("Cancel", role: .cancel) { newRoomName = "" }
                Button("Add") { addRoom() }
                    .disabled(newRoomName.isEmpty)
            } message: {
                Text("Enter a room name, e.g. \"Living Room\" or \"Bedroom 1\".")
            }
        }
    }

    private func addRoom() {
        guard let uid = unitUUID, !newRoomName.isEmpty else { return }
        let room = Room(name: newRoomName.trimmingCharacters(in: .whitespaces), unitID: uid)
        modelContext.insert(room)
        newRoomName = ""
    }
}

private struct RoomScanRow: View {
    let room: Room
    let isScanned: Bool
    let onScan: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isScanned ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isScanned ? .green : .secondary)
                .font(.title3)
            Text(room.name)
                .font(.body)
            Spacer()
            if !isScanned {
                Button("Scan") { onScan() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Button("Re-scan") { onScan() }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
