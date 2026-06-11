import SwiftUI

/// View/edit a single maintenance schedule's active state.
struct MaintenanceScheduleDetailView: View {
    let schedule: PMMaintenanceSchedule
    let maintenanceScheduleService: MaintenanceScheduleService

    private var current: PMMaintenanceSchedule {
        maintenanceScheduleService.schedules.first { $0.id == schedule.id } ?? schedule
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
                LabeledContent("Frequency", value: current.frequency.displayName)
                LabeledContent("Next Due", value: current.nextDueDate)
                if let lastCompleted = current.lastCompletedAt {
                    LabeledContent("Last Completed", value: lastCompleted)
                }
            } header: {
                Text("Schedule")
            }

            Section {
                Toggle("Active", isOn: Binding(
                    get: { current.active },
                    set: { newValue in Task { await maintenanceScheduleService.setActive(current, to: newValue) } }
                ))
            }
        }
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
    }
}
