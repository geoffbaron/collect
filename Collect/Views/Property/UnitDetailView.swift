import SwiftUI

/// PM mode: shows a unit's metadata, inspection history, and starts inspections.
struct UnitDetailView: View {
    let unit: PMUnit
    let unitService: UnitService

    @StateObject private var inspectionService = InspectionService()
    @State private var showInspectionFlow = false
    @State private var activeInspection: PMInspection?
    @State private var showTypeSheet = false
    @State private var selectedType: InspectionTypeEnum = .moveIn

    @StateObject private var workOrderService = WorkOrderService()
    @State private var showNewWorkOrder = false

    @StateObject private var capitalAssetService = CapitalAssetService()
    @State private var showNewCapitalAsset = false

    @StateObject private var maintenanceScheduleService = MaintenanceScheduleService()
    @State private var showNewMaintenanceSchedule = false

    var body: some View {
        List {
            // Errors
            if let error = inspectionService.error {
                ErrorBanner(message: error, onDismiss: { inspectionService.clearError() })
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            if let error = workOrderService.error {
                ErrorBanner(message: error, onDismiss: { workOrderService.clearError() })
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            if let error = capitalAssetService.error {
                ErrorBanner(message: error, onDismiss: { capitalAssetService.clearError() })
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            if let error = maintenanceScheduleService.error {
                ErrorBanner(message: error, onDismiss: { maintenanceScheduleService.clearError() })
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            // Unit info
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
                if let start = unit.leaseStart { LabeledContent("Lease Start", value: start) }
                if let end   = unit.leaseEnd   { LabeledContent("Lease End",   value: end)   }
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

            // Inspections
            Section {
                if inspectionService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else if inspectionService.inspections.isEmpty {
                    Text("No inspections yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(inspectionService.inspections) { inspection in
                        InspectionRow(inspection: inspection) {
                            activeInspection = inspection
                            showInspectionFlow = true
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Inspections")
                    Spacer()
                    Button("New") { showTypeSheet = true }
                        .font(.caption.weight(.medium))
                }
            }

            // Work orders
            Section {
                if workOrderService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else if workOrderService.workOrders.isEmpty {
                    Text("No work orders yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workOrderService.workOrders) { workOrder in
                        NavigationLink {
                            WorkOrderDetailView(workOrder: workOrder, workOrderService: workOrderService)
                        } label: {
                            WorkOrderRow(workOrder: workOrder)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Work Orders")
                    Spacer()
                    Button("New") { showNewWorkOrder = true }
                        .font(.caption.weight(.medium))
                }
            }

            // Capital assets
            Section {
                if capitalAssetService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else if capitalAssetService.capitalAssets.isEmpty {
                    Text("No capital assets yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(capitalAssetService.capitalAssets) { asset in
                        NavigationLink {
                            CapitalAssetDetailView(capitalAsset: asset, capitalAssetService: capitalAssetService)
                        } label: {
                            CapitalAssetRow(asset: asset)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Capital Assets")
                    Spacer()
                    Button("New") { showNewCapitalAsset = true }
                        .font(.caption.weight(.medium))
                }
            }

            // Maintenance schedules
            Section {
                if maintenanceScheduleService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else if maintenanceScheduleService.schedules.isEmpty {
                    Text("No maintenance schedules yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(maintenanceScheduleService.schedules) { schedule in
                        NavigationLink {
                            MaintenanceScheduleDetailView(schedule: schedule, maintenanceScheduleService: maintenanceScheduleService)
                        } label: {
                            MaintenanceScheduleRow(schedule: schedule)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Maintenance Schedules")
                    Spacer()
                    Button("New") { showNewMaintenanceSchedule = true }
                        .font(.caption.weight(.medium))
                }
            }

            if !unit.notes.isEmpty {
                Section("Notes") {
                    Text(unit.notes).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Unit \(unit.unitNumber)")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await inspectionService.load(for: unit.id)
            await workOrderService.load(unitID: unit.id)
            await capitalAssetService.load(unitID: unit.id)
            await maintenanceScheduleService.load(unitID: unit.id)
        }
        .sheet(isPresented: $showInspectionFlow) {
            if let inspection = activeInspection {
                InspectionFlowView(
                    inspection: inspection,
                    unit: unit,
                    inspectionService: inspectionService
                )
            }
        }
        .sheet(isPresented: $showNewWorkOrder) {
            NewWorkOrderView(
                propertyID: unit.propertyID,
                buildingID: unit.buildingID,
                unitID: unit.id,
                workOrderService: workOrderService
            )
        }
        .sheet(isPresented: $showNewCapitalAsset) {
            NewCapitalAssetView(
                propertyID: unit.propertyID,
                buildingID: unit.buildingID,
                unitID: unit.id,
                capitalAssetService: capitalAssetService
            )
        }
        .sheet(isPresented: $showNewMaintenanceSchedule) {
            NewMaintenanceScheduleView(
                propertyID: unit.propertyID,
                buildingID: unit.buildingID,
                unitID: unit.id,
                maintenanceScheduleService: maintenanceScheduleService
            )
        }
        .confirmationDialog("Inspection Type", isPresented: $showTypeSheet, titleVisibility: .visible) {
            ForEach(InspectionTypeEnum.allCases, id: \.self) { type in
                Button(type.displayName) { startInspection(type: type) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose the type of inspection to start.")
        }
    }

    private func startInspection(type: InspectionTypeEnum) {
        let baseline = type == .moveOut ? inspectionService.lastCompletedMoveIn?.id : nil
        Task {
            if let insp = await inspectionService.create(
                unitID: unit.id,
                type: type,
                baselineID: baseline
            ) {
                activeInspection = insp
                showInspectionFlow = true
            }
        }
    }
}

private struct InspectionRow: View {
    let inspection: PMInspection
    let onResume: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(inspection.inspectionType.displayName)
                    .font(.subheadline.weight(.medium))
                Text(inspection.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if inspection.status == .inProgress {
                Button("Resume") { onResume() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Text(inspection.status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
