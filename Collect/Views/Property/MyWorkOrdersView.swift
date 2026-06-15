import SwiftUI

/// Account-wide work order list, server-driven so it works for staff who
/// have no local SwiftData properties. Reached from the portfolio toolbar
/// for managers, and used as the home screen for maintenance-role users.
struct MyWorkOrdersView: View {
    @EnvironmentObject private var accountService: AccountService
    @EnvironmentObject private var authService: AuthService
    @StateObject private var workOrderService = WorkOrderService()
    @State private var filter: Filter?

    enum Filter: String, CaseIterable {
        case mine = "Mine"
        case open = "Open"
        case all  = "All"
        case done = "Done"
    }

    private var currentUserID: String? {
        authService.currentUserID?.lowercased()
    }

    private var filtered: [PMWorkOrder] {
        switch filter ?? .open {
        case .mine: workOrderService.workOrders.filter { $0.assignedTo?.lowercased() == currentUserID }
        case .open: workOrderService.workOrders.filter(\.isOpen)
        case .all:  workOrderService.workOrders
        case .done: workOrderService.workOrders.filter { !$0.isOpen }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let error = workOrderService.error {
                ErrorBanner(message: error, onDismiss: { workOrderService.clearError() })
                    .padding([.horizontal, .top])
            }

            Picker("Filter", selection: Binding(
                get: { filter ?? .open },
                set: { filter = $0 }
            )) {
                ForEach(Filter.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            content
        }
        .navigationTitle("Work Orders")
        .navigationBarTitleDisplayMode(.large)
        .task {
            // Maintenance staff land on their own queue; managers on open tickets.
            if filter == nil {
                filter = accountService.isMaintenance ? .mine : .open
            }
            await workOrderService.loadAll()
        }
        .refreshable { await workOrderService.loadAll() }
    }

    @ViewBuilder
    private var content: some View {
        if workOrderService.isLoading && workOrderService.workOrders.isEmpty {
            Spacer()
            ProgressView("Loading work orders…")
            Spacer()
        } else if filtered.isEmpty {
            ContentUnavailableView {
                Label("No Work Orders", systemImage: "wrench.and.screwdriver")
            } description: {
                Text(emptyDescription)
            }
        } else {
            List {
                ForEach(filtered) { workOrder in
                    NavigationLink {
                        WorkOrderDetailView(workOrder: workOrder, workOrderService: workOrderService)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            WorkOrderRow(workOrder: workOrder)
                            if let location = locationLabel(for: workOrder) {
                                Label(location, systemImage: "mappin.and.ellipse")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyDescription: String {
        switch filter ?? .open {
        case .mine: "Nothing is assigned to you right now."
        case .open: "No open tickets across the portfolio."
        case .all:  "No work orders yet."
        case .done: "No completed or cancelled tickets yet."
        }
    }

    private func locationLabel(for workOrder: PMWorkOrder) -> String? {
        guard let ctx = workOrderService.context[workOrder.id] else { return nil }
        var parts: [String] = []
        if let name = ctx.propertyName { parts.append(name) }
        if let unit = ctx.unitNumber { parts.append("Unit \(unit)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Home screen for maintenance-role users: their work-order queue plus
/// settings. They have no local SwiftData properties, so the regular
/// property list would be empty for them.
struct MaintenanceHomeView: View {
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            MyWorkOrdersView()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "key")
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
        }
    }
}
