import SwiftUI

/// Sheet for creating a maintenance schedule, optionally scoped to a unit.
struct NewMaintenanceScheduleView: View {
    let propertyID: String
    let buildingID: String?
    let unitID: String?
    let maintenanceScheduleService: MaintenanceScheduleService

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var category: WorkOrderCategory = .other
    @State private var frequency: MaintenanceFrequency = .monthly
    @State private var nextDueDate = Date()
    @State private var isSaving = false

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
            }
            .navigationTitle("New Schedule")
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
        let dueDateString = nextDueDate.formatted(.iso8601.year().month().day())
        Task {
            _ = await maintenanceScheduleService.create(
                propertyID: propertyID,
                buildingID: buildingID,
                unitID: unitID,
                title: title.trimmingCharacters(in: .whitespaces),
                description: description,
                category: category,
                frequency: frequency,
                nextDueDate: dueDateString
            )
            isSaving = false
            dismiss()
        }
    }
}
