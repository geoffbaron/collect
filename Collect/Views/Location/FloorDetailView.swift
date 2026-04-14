import SwiftUI
import SwiftData

struct FloorDetailView: View {
    @Bindable var floor: Floor
    @Environment(\.modelContext) private var modelContext
    @State private var showAddRoom = false
    @State private var newRoomName = ""
    @State private var addedNames: Set<String> = []

    private var suggestedRoomNames: [String] {
        ["Living Room", "Kitchen", "Bedroom", "Bathroom", "Office", "Dining Room",
         "Garage", "Laundry Room", "Closet", "Hallway", "Pantry", "Basement"]
    }

    private var unusedSuggestions: [String] {
        let existingNames = Set(floor.rooms.map(\.name)).union(addedNames)
        return suggestedRoomNames.filter { !existingNames.contains($0) }
    }

    var body: some View {
        Group {
            if floor.rooms.isEmpty {
                ContentUnavailableView {
                    Label("No Rooms", systemImage: "door.left.hand.open")
                } description: {
                    Text("Add rooms to start scanning and collecting assets.")
                } actions: {
                    Button("Add Room") {
                        showAddRoom = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    Section("Rooms") {
                        ForEach(floor.sortedRooms) { room in
                            NavigationLink(value: room) {
                                RoomRow(room: room)
                            }
                        }
                        .onDelete(perform: deleteRooms)

                        Button {
                            showAddRoom = true
                        } label: {
                            Label("Add Room", systemImage: "plus.circle")
                                .foregroundStyle(.blue)
                        }
                    }

                    if !unusedSuggestions.isEmpty {
                        Section("Quick Add") {
                            ForEach(unusedSuggestions.prefix(6), id: \.self) { name in
                                Button {
                                    addRoom(name: name)
                                } label: {
                                    Label(name, systemImage: "plus.circle")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
                .navigationDestination(for: Room.self) { room in
                    RoomDetailView(room: room)
                }
            }
        }
        .navigationTitle(floor.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddRoom = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Add Room", isPresented: $showAddRoom) {
            TextField("Room Name", text: $newRoomName)
            Button("Cancel", role: .cancel) { newRoomName = "" }
            Button("Add") {
                addRoom(name: newRoomName)
                newRoomName = ""
            }
            .disabled(newRoomName.isEmpty)
        }
    }

    private func addRoom(name: String) {
        withAnimation {
            addedNames.insert(name)
        }
        let room = Room(name: name, floor: floor)
        modelContext.insert(room)
        try? modelContext.save()
        if let property = floor.property {
            property.updatedAt = Date()
        }
    }

    private func deleteRooms(at offsets: IndexSet) {
        let sorted = floor.sortedRooms
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }
}

struct RoomRow: View {
    let room: Room

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(room.name)
                .font(.headline)

            HStack(spacing: 12) {
                Label("\(room.collections.count) scans", systemImage: "camera.viewfinder")
                Label("\(room.totalAssets) assets", systemImage: "cube.box")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
