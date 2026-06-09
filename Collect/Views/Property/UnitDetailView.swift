import SwiftUI

/// PM mode: shows a unit's metadata and status pickers.
/// Room-level inventory for Phase 3 (inspections) — wired in here when ready.
struct UnitDetailView: View {
    let unit: PMUnit
    let unitService: UnitService

    var body: some View {
        List {
            // Unit header
            Section {
                LabeledContent("Unit", value: unit.unitNumber)
                if let floor = unit.floorNumber {
                    LabeledContent("Floor", value: "\(floor)")
                }
                if !unit.sizeLabel.isEmpty {
                    LabeledContent("Size", value: unit.sizeLabel)
                }
                if let rent = unit.monthlyRent {
                    LabeledContent("Rent", value: rent,
                                   format: .currency(code: "USD").precision(.fractionLength(0)))
                }
            } header: {
                Text("Details")
            }

            // Lease
            Section {
                Picker("Lease Status", selection: Binding(
                    get: { unit.leaseStatus },
                    set: { new in Task { await unitService.updateLeaseStatus(of: unit.id, to: new) } }
                )) {
                    ForEach(LeaseStatus.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }

                if let tenant = unit.currentTenantName {
                    LabeledContent("Tenant", value: tenant)
                }
                if let start = unit.leaseStart {
                    LabeledContent("Lease Start", value: start)
                }
                if let end = unit.leaseEnd {
                    LabeledContent("Lease End", value: end)
                }
            } header: {
                Text("Lease")
            }

            // Turn
            Section {
                Picker("Turn Status", selection: Binding(
                    get: { unit.turnStatus },
                    set: { new in Task { await unitService.updateTurnStatus(of: unit.id, to: new) } }
                )) {
                    ForEach(TurnStatus.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
            } header: {
                Text("Turnover")
            }

            if !unit.notes.isEmpty {
                Section("Notes") {
                    Text(unit.notes)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Unit \(unit.unitNumber)")
        .navigationBarTitleDisplayMode(.large)
    }
}
