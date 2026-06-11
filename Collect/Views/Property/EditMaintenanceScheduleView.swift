import SwiftUI

/// Sheet for editing or deleting an existing maintenance schedule.
struct EditMaintenanceScheduleView: View {
    let schedule: PMMaintenanceSchedule
    let maintenanceScheduleService: MaintenanceScheduleService
    var onDeleted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var category: WorkOrderCategory
    @State private var frequency: MaintenanceFrequency
    @State private var nextDueDate: Date
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    init(schedule: PMMaintenanceSchedule, maintenanceScheduleService: MaintenanceScheduleService, onDeleted: @escaping () -> Void = {}) {
        self.schedule = schedule
        self.maintenanceScheduleService = maintenanceScheduleService
        self.onDeleted = onDeleted
        _title = State(initialValue: schedule.title)
        _description = State(initialValue: schedule.description)
        _category = State(initialValue: schedule.category)
        _frequency = State(initialValue: schedule.frequency)
        _nextDueDate = State(initialValue: Self.dateFormatter.date(from: schedule.nextDueDate) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Schedule") {
                    Picker("Category", selection: $category) {
                        ForEach(WorkOrderCategory.allCases, id: \.self) { c in
                            Label(c.displayName, systemImage: c.systemImage).tag(c)
                        }
                    }
                    Picker("Frequency", selection: $frequency) {
                        ForEach(MaintenanceFrequency.allCases, id: \.self) { f in
                            Text(f.displayName).tag(f)
                        }
                    }
                    DatePicker("Next Due", selection: $nextDueDate, displayedComponents: .date)
                }

                Section {
                    Button("Delete Schedule", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            .navigationTitle("Edit Schedule")
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
                "Delete this maintenance schedule?",
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
        let nextDueDateString = Self.dateFormatter.string(from: nextDueDate)
        Task {
            let success = await maintenanceScheduleService.update(
                schedule,
                title: title.trimmingCharacters(in: .whitespaces),
                description: description,
                category: category,
                frequency: frequency,
                nextDueDate: nextDueDateString
            )
            isSaving = false
            if success { dismiss() }
        }
    }

    private func delete() {
        isSaving = true
        Task {
            let success = await maintenanceScheduleService.delete(schedule)
            isSaving = false
            if success {
                dismiss()
                onDeleted()
            }
        }
    }
}
