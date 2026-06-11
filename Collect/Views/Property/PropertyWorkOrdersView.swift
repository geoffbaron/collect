import SwiftUI

/// PM mode: all work orders across a property (any unit/building/common area).
struct PropertyWorkOrdersView: View {
    let property: Property

    @StateObject private var workOrderService = WorkOrderService()
    @State private var showNewWorkOrder = false

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
        .task { await workOrderService.load(propertyID: property.id.uuidString) }
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
            } else {
                List {
                    ForEach(workOrderService.workOrders) { workOrder in
                        NavigationLink {
                            WorkOrderDetailView(workOrder: workOrder, workOrderService: workOrderService)
                        } label: {
                            WorkOrderRow(workOrder: workOrder)
                        }
                    }
                }
            }
        }
    }
}

/// Shared row for displaying a work order in a list.
struct WorkOrderRow: View {
    let workOrder: PMWorkOrder

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workOrder.category.systemImage)
                .foregroundStyle(workOrder.priority.color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(workOrder.title)
                    .font(.subheadline.weight(.medium))
                Text(workOrder.category.displayName)
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
