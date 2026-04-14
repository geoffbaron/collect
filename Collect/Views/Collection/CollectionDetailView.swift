import SwiftUI
import SwiftData

struct CollectionDetailView: View {
    @Bindable var collection: Collection
    @Environment(\.modelContext) private var modelContext
    @State private var shareItem: ShareItem?

    var body: some View {
        Group {
            if collection.assets.isEmpty {
                ContentUnavailableView {
                    Label("No Assets", systemImage: "cube.box")
                } description: {
                    Text("No items were saved in this scan.")
                }
            } else {
                List {
                    Section {
                        HStack {
                            Label(collection.prompt.displayName, systemImage: collection.prompt.icon)
                                .font(.subheadline)
                            Spacer()
                            StatusBadge(status: collection.status)
                        }
                        HStack {
                            Text("Scanned")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(collection.capturedAt.formatted(date: .long, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }

                    let total = collection.assets.reduce(0.0) { sum, a in
                        sum + (a.estimatedValue ?? 0) * Double(a.quantity)
                    }
                    if total > 0 {
                        Section {
                            HStack {
                                Text("Estimated Total Value")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(total, format: .currency(code: "USD"))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    Section {
                        ForEach(collection.sortedAssets) { asset in
                            NavigationLink(value: asset) {
                                AssetRow(asset: asset)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    if let index = collection.sortedAssets.firstIndex(where: { $0.id == asset.id }) {
                                        deleteAssets(at: IndexSet([index]))
                                    }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text("\(collection.assets.count) Items")
                            .textCase(nil)
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
        .navigationTitle(collection.prompt.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Asset.self) { asset in
            AssetDetailView(asset: asset)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    exportCSV()
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(collection.assets.isEmpty)
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url)
        }
    }

    private func exportCSV() {
        let csv = CSVExporter.csv(for: collection)
        let room = collection.room?.name ?? "Room"
        let date = collection.capturedAt.formatted(.iso8601.year().month().day())
        let filename = "\(room)-\(collection.prompt.displayName)-\(date)"
            .replacingOccurrences(of: " ", with: "-")
        guard let url = CSVExporter.temporaryURL(csv: csv, filename: filename) else { return }
        shareItem = ShareItem(url: url)
    }

    private func deleteAssets(at offsets: IndexSet) {
        let sorted = collection.sortedAssets
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }
}

struct AssetRow: View {
    let asset: Asset

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail from first scan photo
            if let data = asset.photo1Data, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.headline)

                HStack(spacing: 6) {
                    Text(asset.category)
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())

                    if let condition = asset.condition {
                        Text(condition)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if asset.hasLocation {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let val = asset.estimatedValue {
                    Text(val, format: .currency(code: "USD"))
                        .font(.subheadline.weight(.semibold))
                }
                if asset.quantity > 1 {
                    Text("×\(asset.quantity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
