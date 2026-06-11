import SwiftUI

/// Sheet for editing or deleting an existing capital asset.
struct EditCapitalAssetView: View {
    let capitalAsset: PMCapitalAsset
    let capitalAssetService: CapitalAssetService
    var onDeleted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var assetType: CapitalAssetType
    @State private var manufacturer: String
    @State private var model: String
    @State private var serialNumber: String
    @State private var notes: String
    @State private var hasInstallDate: Bool
    @State private var installDate: Date
    @State private var hasWarrantyExpires: Bool
    @State private var warrantyExpires: Date
    @State private var hasLastServicedAt: Bool
    @State private var lastServicedAt: Date
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    init(capitalAsset: PMCapitalAsset, capitalAssetService: CapitalAssetService, onDeleted: @escaping () -> Void = {}) {
        self.capitalAsset = capitalAsset
        self.capitalAssetService = capitalAssetService
        self.onDeleted = onDeleted
        _name = State(initialValue: capitalAsset.name)
        _assetType = State(initialValue: capitalAsset.assetType)
        _manufacturer = State(initialValue: capitalAsset.manufacturer)
        _model = State(initialValue: capitalAsset.model)
        _serialNumber = State(initialValue: capitalAsset.serialNumber)
        _notes = State(initialValue: capitalAsset.notes)

        if let value = capitalAsset.installDate, let parsed = Self.dateFormatter.date(from: value) {
            _hasInstallDate = State(initialValue: true)
            _installDate = State(initialValue: parsed)
        } else {
            _hasInstallDate = State(initialValue: false)
            _installDate = State(initialValue: Date())
        }

        if let value = capitalAsset.warrantyExpires, let parsed = Self.dateFormatter.date(from: value) {
            _hasWarrantyExpires = State(initialValue: true)
            _warrantyExpires = State(initialValue: parsed)
        } else {
            _hasWarrantyExpires = State(initialValue: false)
            _warrantyExpires = State(initialValue: Date())
        }

        if let value = capitalAsset.lastServicedAt, let parsed = Self.dateFormatter.date(from: value) {
            _hasLastServicedAt = State(initialValue: true)
            _lastServicedAt = State(initialValue: parsed)
        } else {
            _hasLastServicedAt = State(initialValue: false)
            _lastServicedAt = State(initialValue: Date())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Asset") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $assetType) {
                        ForEach(CapitalAssetType.allCases, id: \.self) { t in
                            Label(t.displayName, systemImage: t.systemImage).tag(t)
                        }
                    }
                }

                Section("Details") {
                    TextField("Manufacturer", text: $manufacturer)
                    TextField("Model", text: $model)
                    TextField("Serial Number", text: $serialNumber)
                }

                Section {
                    Toggle("Install Date", isOn: $hasInstallDate.animation())
                    if hasInstallDate {
                        DatePicker("Installed", selection: $installDate, displayedComponents: .date)
                    }
                    Toggle("Warranty Expires", isOn: $hasWarrantyExpires.animation())
                    if hasWarrantyExpires {
                        DatePicker("Warranty Expires", selection: $warrantyExpires, displayedComponents: .date)
                    }
                    Toggle("Last Serviced", isOn: $hasLastServicedAt.animation())
                    if hasLastServicedAt {
                        DatePicker("Last Serviced", selection: $lastServicedAt, displayedComponents: .date)
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button("Delete Asset", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            .navigationTitle("Edit Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .confirmationDialog(
                "Delete this capital asset?",
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
        let installDateString = hasInstallDate ? Self.dateFormatter.string(from: installDate) : nil
        let warrantyExpiresString = hasWarrantyExpires ? Self.dateFormatter.string(from: warrantyExpires) : nil
        let lastServicedAtString = hasLastServicedAt ? Self.dateFormatter.string(from: lastServicedAt) : nil
        Task {
            let success = await capitalAssetService.update(
                capitalAsset,
                name: name.trimmingCharacters(in: .whitespaces),
                assetType: assetType,
                manufacturer: manufacturer,
                model: model,
                serialNumber: serialNumber,
                installDate: installDateString,
                warrantyExpires: warrantyExpiresString,
                lastServicedAt: lastServicedAtString,
                notes: notes
            )
            isSaving = false
            if success { dismiss() }
        }
    }

    private func delete() {
        isSaving = true
        Task {
            let success = await capitalAssetService.delete(capitalAsset)
            isSaving = false
            if success {
                dismiss()
                onDeleted()
            }
        }
    }
}
