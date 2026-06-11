import SwiftUI

/// View/edit a single capital asset's condition.
struct CapitalAssetDetailView: View {
    let capitalAsset: PMCapitalAsset
    let capitalAssetService: CapitalAssetService

    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false

    private var current: PMCapitalAsset {
        capitalAssetService.capitalAssets.first { $0.id == capitalAsset.id } ?? capitalAsset
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Name", value: current.name)
                LabeledContent("Type") {
                    Label(current.assetType.displayName, systemImage: current.assetType.systemImage)
                }
            }

            Section {
                if !current.manufacturer.isEmpty {
                    LabeledContent("Manufacturer", value: current.manufacturer)
                }
                if !current.model.isEmpty {
                    LabeledContent("Model", value: current.model)
                }
                if !current.serialNumber.isEmpty {
                    LabeledContent("Serial Number", value: current.serialNumber)
                }
                if let installDate = current.installDate {
                    LabeledContent("Installed", value: installDate.formattedAsDateOnly)
                }
                if let warrantyExpires = current.warrantyExpires {
                    LabeledContent("Warranty Expires", value: warrantyExpires.formattedAsDateOnly)
                }
                if let lastServicedAt = current.lastServicedAt {
                    LabeledContent("Last Serviced", value: lastServicedAt.formattedAsDateOnly)
                }
            } header: {
                Text("Details")
            }

            Section {
                Picker("Condition", selection: Binding(
                    get: { current.condition },
                    set: { newCondition in Task { await capitalAssetService.updateCondition(current, to: newCondition) } }
                )) {
                    ForEach(CapitalAssetCondition.allCases, id: \.self) { condition in
                        Text(condition.displayName).tag(condition)
                    }
                }
            } header: {
                Text("Condition")
            }

            if !current.notes.isEmpty {
                Section("Notes") {
                    Text(current.notes).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Asset")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditCapitalAssetView(capitalAsset: current, capitalAssetService: capitalAssetService, onDeleted: { dismiss() })
        }
    }
}
