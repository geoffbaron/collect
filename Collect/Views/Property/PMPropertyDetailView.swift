import SwiftUI

/// PM mode: shows buildings for a property with vacancy summary chips.
/// Replaces PropertyDetailView when accountService.isPropertyManager is true.
struct PMPropertyDetailView: View {
    let property: Property

    @StateObject private var buildingService = BuildingService()
    @StateObject private var commonAreaService = CommonAreaService()
    @State private var showAddBuilding = false
    @State private var newBuildingName = ""
    @State private var newBuildingAddress = ""
    @State private var showAddCommonArea = false

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
                    PropertyMaintenanceSchedulesView(property: property)
                } label: {
                    Image(systemName: "calendar.badge.clock")
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
        .sheet(isPresented: $showAddCommonArea) {
            NewCommonAreaView(
                propertyID: property.id.uuidString,
                commonAreaService: commonAreaService
            )
        }
        .task {
            await buildingService.load(for: property.id.uuidString)
            await commonAreaService.load(for: property.id.uuidString)
        }
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
            if let error = commonAreaService.error {
                ErrorBanner(message: error, onDismiss: { commonAreaService.clearError() })
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            Section("Buildings") {
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

            Section("Common Areas") {
                ForEach(commonAreaService.commonAreas) { area in
                    HStack(spacing: 12) {
                        Image(systemName: area.areaType.systemImage)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(area.name)
                                .font(.subheadline.weight(.medium))
                            Text(area.areaType.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            Task { _ = await commonAreaService.delete(area) }
                        }
                    }
                }
                Button {
                    showAddCommonArea = true
                } label: {
                    Label("Add Common Area", systemImage: "plus.circle")
                        .foregroundStyle(.blue)
                }
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

/// Sheet for creating a common area on a property.
private struct NewCommonAreaView: View {
    let propertyID: String
    let commonAreaService: CommonAreaService

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var areaType: CommonAreaType = .other
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $areaType) {
                        ForEach(CommonAreaType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.systemImage).tag(type)
                        }
                    }
                } footer: {
                    Text("Shared spaces like lobbies, gyms, and laundry rooms can be targeted by work orders, capital assets, and maintenance schedules.")
                }
            }
            .navigationTitle("New Common Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func create() {
        isSaving = true
        Task {
            _ = await commonAreaService.create(
                propertyID: propertyID,
                name: name,
                areaType: areaType
            )
            isSaving = false
            dismiss()
        }
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
