import SwiftUI
import SwiftData

struct PropertyDetailView: View {
    @Bindable var property: Property
    @EnvironmentObject private var featuresService: FeaturesService
    @Environment(\.modelContext) private var modelContext
    @State private var showAddFloor = false
    @State private var newFloorName = ""
    @State private var showEditProperty = false
    @State private var shareItem: ShareItem?
    @State private var showFloorPlan = false
    @State private var showPropertyMap = false

    var body: some View {
        Group {
            if property.floors.isEmpty {
                ContentUnavailableView {
                    Label("No Floors", systemImage: "square.stack.3d.up")
                } description: {
                    Text("Add floors to organize rooms within this property.")
                } actions: {
                    Button("Add Floor") {
                        showAddFloor = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    if !property.address.isEmpty {
                        Section {
                            Label(property.address, systemImage: "mappin.and.ellipse")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Floors") {
                        ForEach(property.sortedFloors) { floor in
                            NavigationLink(value: floor) {
                                FloorRow(floor: floor)
                            }
                        }
                        .onDelete(perform: deleteFloors)

                        Button {
                            showAddFloor = true
                        } label: {
                            Label("Add Floor", systemImage: "plus.circle")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .navigationDestination(for: Floor.self) { floor in
                    FloorDetailView(floor: floor)
                }
            }
        }
        .navigationTitle(property.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddFloor = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEditProperty = true
                    } label: {
                        Label("Edit Property", systemImage: "pencil")
                    }

                    if featuresService.floorScansEnabled {
                        Button {
                            showFloorPlan = true
                        } label: {
                            Label("Floor Plans", systemImage: "square.grid.2x2")
                        }
                    }

                    if featuresService.locationEnabled {
                        Button {
                            showPropertyMap = true
                        } label: {
                            Label("Property Map", systemImage: "map")
                        }
                    }

                    Button {
                        exportCSV()
                    } label: {
                        Label("Export All as CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(property.totalCollections == 0)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url)
        }
        .sheet(isPresented: $showFloorPlan) {
            NavigationStack {
                PropertyFloorPlanView(property: property)
            }
        }
        .sheet(isPresented: $showPropertyMap) {
            NavigationStack {
                PropertyMapView(property: property)
            }
        }
        .alert("Add Floor", isPresented: $showAddFloor) {
            TextField("Floor Name (e.g., 1st Floor)", text: $newFloorName)
            Button("Cancel", role: .cancel) { newFloorName = "" }
            Button("Add") { addFloor() }
                .disabled(newFloorName.isEmpty)
        }
        .alert("Edit Property", isPresented: $showEditProperty) {
            TextField("Name", text: $property.name)
            TextField("Address", text: $property.address)
            Button("Done", role: .cancel) {}
        }
    }

    private func exportCSV() {
        let csv = CSVExporter.csv(for: property)
        let filename = property.name
            .replacingOccurrences(of: " ", with: "-")
        guard let url = CSVExporter.temporaryURL(csv: csv, filename: filename) else { return }
        shareItem = ShareItem(url: url)
    }

    private func addFloor() {
        guard !newFloorName.isEmpty else { return }
        let floor = Floor(name: newFloorName, sortOrder: property.floors.count, property: property)
        modelContext.insert(floor)
        property.updatedAt = Date()
        newFloorName = ""
    }

    private func deleteFloors(at offsets: IndexSet) {
        let sorted = property.sortedFloors
        for index in offsets {
            modelContext.delete(sorted[index])
        }
        property.updatedAt = Date()
    }
}

struct FloorRow: View {
    let floor: Floor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(floor.name)
                .font(.headline)

            HStack(spacing: 12) {
                Label("\(floor.rooms.count) rooms", systemImage: "door.left.hand.open")
                Label("\(floor.totalCollections) scans", systemImage: "camera.viewfinder")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
