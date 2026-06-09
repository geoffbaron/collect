import SwiftUI

/// PM mode: shows the units grid for a building with lease/turn status badges.
struct BuildingDetailView: View {
    let property: Property
    let building: PMBuilding

    @StateObject private var unitService = UnitService()
    @State private var showAddUnit = false
    @State private var newUnitNumber = ""
    @State private var filterStatus: LeaseStatus? = nil

    private var displayedUnits: [PMUnit] {
        guard let f = filterStatus else { return unitService.units }
        return unitService.units.filter { $0.leaseStatus == f }
    }

    var body: some View {
        Group {
            if unitService.isLoading && unitService.units.isEmpty {
                ProgressView("Loading units…")
            } else if unitService.units.isEmpty {
                emptyState
            } else {
                unitContent
            }
        }
        .navigationTitle(building.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddUnit = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Add Unit", isPresented: $showAddUnit) {
            TextField("Unit Number (e.g. 101)", text: $newUnitNumber)
            Button("Cancel", role: .cancel) { newUnitNumber = "" }
            Button("Add") { addUnit() }
                .disabled(newUnitNumber.isEmpty)
        }
        .task { await unitService.load(for: building.id) }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Units", systemImage: "door.right.hand.closed")
        } description: {
            Text("Add units to track leases and inspections.")
        } actions: {
            Button("Add Unit") { showAddUnit = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var unitContent: some View {
        List {
            // Vacancy summary
            Section {
                HStack(spacing: 12) {
                    VacancyChip(label: "Total",    count: unitService.units.count, color: .secondary)
                    VacancyChip(label: "Vacant",   count: unitService.vacantCount,   color: .secondary)
                    VacancyChip(label: "Occupied", count: unitService.occupiedCount, color: .green)
                    if unitService.needsTurnCount > 0 {
                        VacancyChip(label: "Turn", count: unitService.needsTurnCount, color: .orange)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // Filter pills
            if unitService.units.count > 5 {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(label: "All", active: filterStatus == nil) {
                                filterStatus = nil
                            }
                            ForEach(LeaseStatus.allCases, id: \.self) { s in
                                FilterChip(label: s.displayName, active: filterStatus == s) {
                                    filterStatus = filterStatus == s ? nil : s
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }

            Section {
                ForEach(displayedUnits) { unit in
                    NavigationLink(value: unit) {
                        UnitRow(unit: unit)
                    }
                    .swipeActions(edge: .trailing) {
                        Menu {
                            ForEach(LeaseStatus.allCases, id: \.self) { s in
                                Button(s.displayName) {
                                    Task { await unitService.updateLeaseStatus(of: unit.id, to: s) }
                                }
                            }
                        } label: {
                            Label("Lease Status", systemImage: "person.badge.key")
                        }
                        .tint(.blue)
                    }
                }
            }

            Button {
                showAddUnit = true
            } label: {
                Label("Add Unit", systemImage: "plus.circle")
                    .foregroundStyle(.blue)
            }
        }
        .navigationDestination(for: PMUnit.self) { unit in
            UnitDetailView(unit: unit, unitService: unitService)
        }
    }

    private func addUnit() {
        let number = newUnitNumber
        Task {
            await unitService.create(
                propertyID: property.id.uuidString,
                buildingID: building.id,
                unitNumber: number
            )
        }
        newUnitNumber = ""
    }
}

// MARK: - Helper Views

private struct UnitRow: View {
    let unit: PMUnit

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Unit \(unit.unitNumber)")
                    .font(.headline)
                if !unit.sizeLabel.isEmpty {
                    Text(unit.sizeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let tenant = unit.currentTenantName {
                    Text(tenant)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                UnitStatusBadge(label: unit.leaseStatus.displayName, color: unit.leaseStatus.color)
                if unit.turnStatus != .clean {
                    UnitStatusBadge(label: unit.turnStatus.displayName, color: unit.turnStatus.color)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct UnitStatusBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

private struct VacancyChip: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            Text("\(count)").font(.headline).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FilterChip: View {
    let label: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(active ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
                .foregroundStyle(active ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
