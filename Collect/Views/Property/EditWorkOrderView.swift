import SwiftUI

/// Sheet for editing or deleting an existing work order.
struct EditWorkOrderView: View {
    let workOrder: PMWorkOrder
    let workOrderService: WorkOrderService
    var onDeleted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var category: WorkOrderCategory
    @State private var priority: WorkOrderPriority
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    init(workOrder: PMWorkOrder, workOrderService: WorkOrderService, onDeleted: @escaping () -> Void = {}) {
        self.workOrder = workOrder
        self.workOrderService = workOrderService
        self.onDeleted = onDeleted
        _title = State(initialValue: workOrder.title)
        _description = State(initialValue: workOrder.description)
        _category = State(initialValue: workOrder.category)
        _priority = State(initialValue: workOrder.priority)
        if let dueDateString = workOrder.dueDate, let parsed = Self.dateFormatter.date(from: dueDateString) {
            _hasDueDate = State(initialValue: true)
            _dueDate = State(initialValue: parsed)
        } else {
            _hasDueDate = State(initialValue: false)
            _dueDate = State(initialValue: Date())
        }
    }

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
                }

                Section {
                    Toggle("Due Date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section {
                    Button("Delete Work Order", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            .navigationTitle("Edit Work Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .confirmationDialog(
                "Delete this work order?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    private func save() {
        isSaving = true
        let dueDateString: String? = hasDueDate
            ? Self.dateFormatter.string(from: dueDate)
            : nil
        Task {
            let success = await workOrderService.update(
                workOrder,
                title: title.trimmingCharacters(in: .whitespaces),
                description: description,
                category: category,
                priority: priority,
                dueDate: dueDateString
            )
            isSaving = false
            if success { dismiss() }
        }
    }

    private func delete() {
        isSaving = true
        Task {
            let success = await workOrderService.delete(workOrder)
            isSaving = false
            if success {
                dismiss()
                onDeleted()
            }
        }
    }
}
