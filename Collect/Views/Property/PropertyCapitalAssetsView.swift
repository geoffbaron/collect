import SwiftUI

/// PM mode: all capital assets across a property (any unit/building/common area).
struct PropertyCapitalAssetsView: View {
    let property: Property

    @StateObject private var capitalAssetService = CapitalAssetService()
    @State private var showNewCapitalAsset = false

    var body: some View {
        Group {
            if capitalAssetService.isLoading && capitalAssetService.capitalAssets.isEmpty {
                ProgressView("Loading assets…")
            } else if capitalAssetService.capitalAssets.isEmpty {
                ContentUnavailableView {
                    Label("No Capital Assets", systemImage: "cube.box")
                } description: {
                    Text("Major systems and equipment for this property will appear here.")
                } actions: {
                    Button("New Asset") { showNewCapitalAsset = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(capitalAssetService.capitalAssets) { asset in
                        NavigationLink {
                            CapitalAssetDetailView(capitalAsset: asset, capitalAssetService: capitalAssetService)
                        } label: {
                            CapitalAssetRow(asset: asset)
                        }
                    }
                }
            }
        }
        .navigationTitle("Capital Assets")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewCapitalAsset = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewCapitalAsset) {
            NewCapitalAssetView(
                propertyID: property.id.uuidString,
                buildingID: nil,
                unitID: nil,
                capitalAssetService: capitalAssetService
            )
        }
        .task { await capitalAssetService.load(propertyID: property.id.uuidString) }
    }
}

/// Shared row for displaying a capital asset in a list.
struct CapitalAssetRow: View {
    let asset: PMCapitalAsset

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: asset.assetType.systemImage)
                .foregroundStyle(asset.condition.color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .font(.subheadline.weight(.medium))
                Text(asset.assetType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(asset.condition.displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(asset.condition.color)
        }
        .padding(.vertical, 2)
    }
}
