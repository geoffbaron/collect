import SwiftUI

/// Sheet for editing a unit's details and lease/tenant fields, or deleting
/// the unit. Status pickers stay inline in UnitDetailView.
struct EditUnitView: View {
    let unit: PMUnit
    let unitService: UnitService
    var onDeleted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var unitNumber: String
    @State private var floorNumber: String
    @State private var sqft: String
    @State private var bedrooms: String
    @State private var bathrooms: String
    @State private var tenantName: String
    @State private var hasLeaseStart: Bool
    @State private var leaseStart: Date
    @State private var hasLeaseEnd: Bool
    @State private var leaseEnd: Date
    @State private var monthlyRent: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    init(unit: PMUnit, unitService: UnitService, onDeleted: @escaping () -> Void = {}) {
        self.unit = unit
        self.unitService = unitService
        self.onDeleted = onDeleted
        _unitNumber  = State(initialValue: unit.unitNumber)
        _floorNumber = State(initialValue: unit.floorNumber.map(String.init) ?? "")
        _sqft        = State(initialValue: unit.sqft.map(String.init) ?? "")
        _bedrooms    = State(initialValue: unit.bedrooms.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "")
        _bathrooms   = State(initialValue: unit.bathrooms.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "")
        _tenantName  = State(initialValue: unit.currentTenantName ?? "")
        _monthlyRent = State(initialValue: unit.monthlyRent.map { $0.formatted(.number.precision(.fractionLength(0...2))) } ?? "")
        _notes       = State(initialValue: unit.notes)
        if let start = unit.leaseStart, let parsed = Self.dateFormatter.date(from: start) {
            _hasLeaseStart = State(initialValue: true)
            _leaseStart = State(initialValue: parsed)
        } else {
            _hasLeaseStart = State(initialValue: false)
            _leaseStart = State(initialValue: Date())
        }
        if let end = unit.leaseEnd, let parsed = Self.dateFormatter.date(from: end) {
            _hasLeaseEnd = State(initialValue: true)
            _leaseEnd = State(initialValue: parsed)
        } else {
            _hasLeaseEnd = State(initialValue: false)
            _leaseEnd = State(initialValue: Date())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Unit") {
                    TextField("Unit Number", text: $unitNumber)
                    TextField("Floor", text: $floorNumber)
                        .keyboardType(.numberPad)
                    TextField("Sqft", text: $sqft)
                        .keyboardType(.numberPad)
                    TextField("Bedrooms", text: $bedrooms)
                        .keyboardType(.decimalPad)
                    TextField("Bathrooms", text: $bathrooms)
                        .keyboardType(.decimalPad)
                }

                Section("Lease & Tenant") {
                    TextField("Tenant Name", text: $tenantName)
                    TextField("Monthly Rent ($)", text: $monthlyRent)
                        .keyboardType(.decimalPad)
                    Toggle("Lease Start", isOn: $hasLeaseStart.animation())
                    if hasLeaseStart {
                        DatePicker("Start", selection: $leaseStart, displayedComponents: .date)
                    }
                    Toggle("Lease End", isOn: $hasLeaseEnd.animation())
                    if hasLeaseEnd {
                        DatePicker("End", selection: $leaseEnd, displayedComponents: .date)
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button("Delete Unit", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            .navigationTitle("Edit Unit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(unitNumber.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .confirmationDialog(
                "Delete this unit?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Its inspection and work-order history will no longer appear in the portfolio.")
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            let success = await unitService.update(
                unit,
                unitNumber: unitNumber,
                floorNumber: Int(floorNumber.trimmingCharacters(in: .whitespaces)),
                sqft: Int(sqft.trimmingCharacters(in: .whitespaces)),
                bedrooms: Double(bedrooms.trimmingCharacters(in: .whitespaces)),
                bathrooms: Double(bathrooms.trimmingCharacters(in: .whitespaces)),
                currentTenantName: tenantName.trimmingCharacters(in: .whitespaces),
                leaseStart: hasLeaseStart ? Self.dateFormatter.string(from: leaseStart) : nil,
                leaseEnd: hasLeaseEnd ? Self.dateFormatter.string(from: leaseEnd) : nil,
                monthlyRent: Double(monthlyRent.trimmingCharacters(in: .whitespaces)),
                notes: notes
            )
            isSaving = false
            if success { dismiss() }
        }
    }

    private func delete() {
        isSaving = true
        Task {
            let success = await unitService.delete(unit)
            isSaving = false
            if success {
                dismiss()
                onDeleted()
            }
        }
    }
}
