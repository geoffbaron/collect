import SwiftUI

/// Sheet for creating a capital asset, optionally scoped to a unit.
struct NewCapitalAssetView: View {
    let propertyID: String
    let buildingID: String?
    let unitID: String?
    let capitalAssetService: CapitalAssetService

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var assetType: CapitalAssetType = .other
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var serialNumber = ""
    @State private var condition: CapitalAssetCondition = .good
    @State private var hasInstallDate = false
    @State private var installDate = Date()
    @State private var isSaving = false

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
                    Picker("Condition", selection: $condition) {
                        ForEach(CapitalAssetCondition.allCases, id: \.self) { c in
                            Text(c.displayName).tag(c)
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
                }
            }
            .navigationTitle("New Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func create() {
        isSaving = true
        let installDateString: String? = hasInstallDate
            ? installDate.formatted(.iso8601.year().month().day())
            : nil
        Task {
            _ = await capitalAssetService.create(
                propertyID: propertyID,
                buildingID: buildingID,
                unitID: unitID,
                name: name.trimmingCharacters(in: .whitespaces),
                assetType: assetType,
                manufacturer: manufacturer,
                model: model,
                serialNumber: serialNumber,
                installDate: installDateString,
                condition: condition
            )
            isSaving = false
            dismiss()
        }
    }
}
