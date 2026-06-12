import SwiftUI

/// Sheet for creating a work order, optionally scoped to a unit.
struct NewWorkOrderView: View {
    let propertyID: String
    let buildingID: String?
    let unitID: String?
    let workOrderService: WorkOrderService

    @EnvironmentObject private var accountService: AccountService
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var category: WorkOrderCategory = .other
    @State private var priority: WorkOrderPriority = .medium
    @State private var assignedTo = "" // empty = unassigned
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Issue") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Details") {
                    Picker("Category", selection: $category) {
                        ForEach(WorkOrderCategory.allCases, id: \.self) { c in
                            Label(c.displayName, systemImage: c.systemImage).tag(c)
                        }
                    }
                    Picker("Priority", selection: $priority) {
                        ForEach(WorkOrderPriority.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    Picker("Assign To", selection: $assignedTo) {
                        Text("Unassigned").tag("")
                        ForEach(accountService.members) { member in
                            Text(member.displayName).tag(member.userID)
                        }
                    }
                }

                Section {
                    Toggle("Due Date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    }
                }
            }
            .task { await accountService.loadMembers() }
            .navigationTitle("New Work Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func create() {
        isSaving = true
        let dueDateString: String? = hasDueDate
            ? dueDate.formatted(.iso8601.year().month().day())
            : nil
        Task {
            _ = await workOrderService.create(
                propertyID: propertyID,
                buildingID: buildingID,
                unitID: unitID,
                title: title.trimmingCharacters(in: .whitespaces),
                description: description,
                category: category,
                priority: priority,
                dueDate: dueDateString,
                assignedTo: assignedTo.isEmpty ? nil : assignedTo
            )
            isSaving = false
            dismiss()
        }
    }
}
