import SwiftUI

/// View/edit a single work order's status.
struct WorkOrderDetailView: View {
    let workOrder: PMWorkOrder
    let workOrderService: WorkOrderService

    @EnvironmentObject private var accountService: AccountService
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false

    private var current: PMWorkOrder {
        workOrderService.workOrders.first { $0.id == workOrder.id } ?? workOrder
    }

    private var assigneeName: String? {
        guard let assignedTo = current.assignedTo else { return nil }
        return accountService.members.first { $0.userID == assignedTo }?.displayName ?? "Teammate"
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Title", value: current.title)
                if !current.description.isEmpty {
                    Text(current.description)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                LabeledContent("Category") {
                    Label(current.category.displayName, systemImage: current.category.systemImage)
                }
                LabeledContent("Priority") {
                    Text(current.priority.displayName)
                        .foregroundStyle(current.priority.color)
                }
                LabeledContent("Assigned To", value: assigneeName ?? "Unassigned")
                if let dueDate = current.dueDate {
                    LabeledContent("Due", value: dueDate.formattedAsDateOnly)
                }
            } header: {
                Text("Details")
            }

            Section {
                Picker("Status", selection: Binding(
                    get: { current.status },
                    set: { newStatus in Task { await workOrderService.updateStatus(current, to: newStatus) } }
                )) {
                    ForEach(WorkOrderStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                if let completedAt = current.completedAt {
                    LabeledContent("Completed", value: completedAt, format: .dateTime.month().day().year())
                }
            } header: {
                Text("Status")
            }

            Section {
                LabeledContent("Reported", value: current.createdAt, format: .dateTime.month().day().year())
            }
        }
        .task { await accountService.loadMembers() }
        .navigationTitle("Work Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditWorkOrderView(workOrder: current, workOrderService: workOrderService, onDeleted: { dismiss() })
        }
    }
}
