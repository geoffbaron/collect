import SwiftUI
import SwiftData

struct PropertyListView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Property.updatedAt, order: .reverse) private var properties: [Property]
    @State private var showAddProperty = false
    @State private var newPropertyName = ""
    @State private var newPropertyAddress = ""
    @State private var showSettings = false

    private var userProperties: [Property] {
        properties.filter { $0.ownerID == authService.currentUserID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if userProperties.isEmpty {
                    emptyState
                } else {
                    propertyList
                }
            }
            .navigationTitle("Properties")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "key")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddProperty = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert("New Property", isPresented: $showAddProperty) {
                TextField("Property Name", text: $newPropertyName)
                TextField("Address (optional)", text: $newPropertyAddress)
                Button("Cancel", role: .cancel) { resetForm() }
                Button("Add") { addProperty() }
                    .disabled(newPropertyName.isEmpty)
            } message: {
                Text("Enter the name and address for the new property.")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Properties", systemImage: "building.2")
        } description: {
            Text("Add a property to start collecting room inventories.")
        } actions: {
            Button("Add Property") {
                showAddProperty = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var propertyList: some View {
        List {
            ForEach(userProperties) { property in
                NavigationLink(value: property) {
                    PropertyRow(property: property)
                }
            }
            .onDelete(perform: deleteProperties)

            Button {
                showAddProperty = true
            } label: {
                Label("Add Property", systemImage: "plus.circle")
                    .foregroundStyle(.blue)
            }
        }
        .navigationDestination(for: Property.self) { property in
            PropertyDetailView(property: property)
        }
        .navigationDestination(for: Collection.self) { collection in
            CollectionDetailView(collection: collection)
        }
        .navigationDestination(for: Asset.self) { asset in
            AssetDetailView(asset: asset)
        }
    }

    private func addProperty() {
        guard !newPropertyName.isEmpty, let userID = authService.currentUserID else { return }
        let property = Property(name: newPropertyName, address: newPropertyAddress, ownerID: userID)
        modelContext.insert(property)
        resetForm()
    }

    private func deleteProperties(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(userProperties[index])
        }
    }

    private func resetForm() {
        newPropertyName = ""
        newPropertyAddress = ""
    }
}

struct PropertyRow: View {
    let property: Property

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(property.name)
                .font(.headline)

            if !property.address.isEmpty {
                Text(property.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Label("\(property.floors.count) floors", systemImage: "square.stack.3d.up")
                Label("\(property.totalRooms) rooms", systemImage: "door.left.hand.open")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
