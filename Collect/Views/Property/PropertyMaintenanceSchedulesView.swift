import SwiftUI

/// PM mode: all maintenance schedules across a property (any unit/building/common area).
struct PropertyMaintenanceSchedulesView: View {
    let property: Property

    @StateObject private var maintenanceScheduleService = MaintenanceScheduleService()
    @State private var showNewSchedule = false

    var body: some View {
        Group {
            if maintenanceScheduleService.isLoading && maintenanceScheduleService.schedules.isEmpty {
                ProgressView("Loading schedules…")
            } else if maintenanceScheduleService.schedules.isEmpty {
                ContentUnavailableView {
                    Label("No Schedules", systemImage: "calendar.badge.clock")
                } description: {
                    Text("Recurring maintenance tasks for this property will appear here.")
                } actions: {
                    Button("New Schedule") { showNewSchedule = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(maintenanceScheduleService.schedules) { schedule in
                        NavigationLink {
                            MaintenanceScheduleDetailView(schedule: schedule, maintenanceScheduleService: maintenanceScheduleService)
                        } label: {
                            MaintenanceScheduleRow(schedule: schedule)
                        }
                    }
                }
            }
        }
        .navigationTitle("Maintenance Schedules")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewSchedule = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewSchedule) {
            NewMaintenanceScheduleView(
                propertyID: property.id.uuidString,
                buildingID: nil,
                unitID: nil,
                maintenanceScheduleService: maintenanceScheduleService
            )
        }
        .task { await maintenanceScheduleService.load(propertyID: property.id.uuidString) }
    }
}

/// Shared row for displaying a maintenance schedule in a list.
struct MaintenanceScheduleRow: View {
    let schedule: PMMaintenanceSchedule

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: schedule.category.systemImage)
                .foregroundStyle(schedule.isOverdue ? .red : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.title)
                    .font(.subheadline.weight(.medium))
                Text(schedule.frequency.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Due \(schedule.nextDueDate)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(schedule.isOverdue ? .red : .secondary)
                if !schedule.active {
                    Text("Inactive")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
