import SwiftUI

/// PM mode: all work orders across a property (any unit/building/common area).
struct PropertyWorkOrdersView: View {
    let property: Property

    @EnvironmentObject private var accountService: AccountService
    @StateObject private var workOrderService = WorkOrderService()
    @State private var showNewWorkOrder = false
    @State private var statusFilter: WorkOrderStatus?

    private var filtered: [PMWorkOrder] {
        guard let statusFilter else { return workOrderService.workOrders }
        return workOrderService.workOrders.filter { $0.status == statusFilter }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let error = workOrderService.error {
                ErrorBanner(message: error, onDismiss: { workOrderService.clearError() })
                    .padding([.horizontal, .top])
            }
            content
        }
        .navigationTitle("Work Orders")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Status", selection: $statusFilter) {
                        Text("All Statuses").tag(WorkOrderStatus?.none)
                        ForEach(WorkOrderStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(WorkOrderStatus?.some(status))
                        }
                    }
                } label: {
                    Image(systemName: statusFilter == nil
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewWorkOrder = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewWorkOrder) {
            NewWorkOrderView(
                propertyID: property.id.uuidString,
                buildingID: nil,
                unitID: nil,
                workOrderService: workOrderService
            )
        }
        .task {
            await workOrderService.load(propertyID: property.id.uuidString)
            await accountService.loadMembers()
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if workOrderService.isLoading && workOrderService.workOrders.isEmpty {
                ProgressView("Loading work orders…")
            } else if workOrderService.workOrders.isEmpty {
                ContentUnavailableView {
                    Label("No Work Orders", systemImage: "wrench.and.screwdriver")
                } description: {
                    Text("Maintenance tickets for this property will appear here.")
                } actions: {
                    Button("New Work Order") { showNewWorkOrder = true }
                        .buttonStyle(.borderedProminent)
                }
            } else if filtered.isEmpty {
                ContentUnavailableView {
                    Label("No Work Orders", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("No \(statusFilter?.displayName.lowercased() ?? "") tickets for this property.")
                }
            } else {
                List {
                    ForEach(filtered) { workOrder in
                        NavigationLink {
                            WorkOrderDetailView(workOrder: workOrder, workOrderService: workOrderService)
                        } label: {
                            WorkOrderRow(workOrder: workOrder, assigneeName: assigneeName(for: workOrder))
                        }
                    }
                }
            }
        }
    }

    private func assigneeName(for workOrder: PMWorkOrder) -> String? {
        guard let assignedTo = workOrder.assignedTo else { return nil }
        return accountService.members.first { $0.userID == assignedTo }?.displayName
    }
}

/// Shared row for displaying a work order in a list.
struct WorkOrderRow: View {
    let workOrder: PMWorkOrder
    var assigneeName: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workOrder.category.systemImage)
                .foregroundStyle(workOrder.priority.color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(workOrder.title)
                    .font(.subheadline.weight(.medium))
                Text(assigneeName.map { "\(workOrder.category.displayName) · \($0)" }
                     ?? workOrder.category.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(workOrder.status.displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(workOrder.status.color)
        }
        .padding(.vertical, 2)
    }
}
