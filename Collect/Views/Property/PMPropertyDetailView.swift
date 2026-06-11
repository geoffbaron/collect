import SwiftUI

/// PM mode: shows buildings for a property with vacancy summary chips.
/// Replaces PropertyDetailView when accountService.isPropertyManager is true.
struct PMPropertyDetailView: View {
    let property: Property

    @StateObject private var buildingService = BuildingService()
    @State private var showAddBuilding = false
    @State private var newBuildingName = ""
    @State private var newBuildingAddress = ""

    var body: some View {
        Group {
            if buildingService.isLoading && buildingService.buildings.isEmpty {
                ProgressView("Loading buildings…")
            } else if buildingService.buildings.isEmpty {
                emptyState
            } else {
                buildingList
            }
        }
        .navigationTitle(property.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    PropertyCapitalAssetsView(property: property)
                } label: {
                    Image(systemName: "cube.box")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    PropertyWorkOrdersView(property: property)
                } label: {
                    Image(systemName: "wrench.and.screwdriver")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddBuilding = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Add Building", isPresented: $showAddBuilding) {
            TextField("Building Name", text: $newBuildingName)
            TextField("Address (optional)", text: $newBuildingAddress)
            Button("Cancel", role: .cancel) { resetForm() }
            Button("Add") { addBuilding() }
                .disabled(newBuildingName.isEmpty)
        } message: {
            Text(#"Give this building a name, e.g. "Building A" or "North Tower"."#)
        }
        .task { await buildingService.load(for: property.id.uuidString) }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Buildings", systemImage: "building.2")
        } description: {
            Text("Add buildings to organize your units.")
        } actions: {
            Button("Add Building") { showAddBuilding = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var buildingList: some View {
        List {
            ForEach(buildingService.buildings) { building in
                NavigationLink(value: building) {
                    BuildingRow(building: building)
                }
            }
            Button {
                showAddBuilding = true
            } label: {
                Label("Add Building", systemImage: "plus.circle")
                    .foregroundStyle(.blue)
            }
        }
        .navigationDestination(for: PMBuilding.self) { building in
            BuildingDetailView(property: property, building: building)
        }
    }

    private func addBuilding() {
        let name    = newBuildingName
        let address = newBuildingAddress
        Task {
            await buildingService.create(
                propertyID: property.id.uuidString,
                name: name,
                address: address
            )
        }
        resetForm()
    }

    private func resetForm() {
        newBuildingName    = ""
        newBuildingAddress = ""
    }
}

private struct BuildingRow: View {
    let building: PMBuilding

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(building.name)
                .font(.headline)
            if !building.address.isEmpty {
                Text(building.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
