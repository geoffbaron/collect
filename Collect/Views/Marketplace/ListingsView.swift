import SwiftUI
import SwiftData

struct ListingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var syncService: SyncService
    @Environment(\.modelContext) private var modelContext
    @Query private var allAssets: [Asset]

    @State private var filter: ListingStatus = .ready
    @State private var assetToSell: Asset?
    @State private var soldAsset: Asset?

    // Assets that have ever been listed/pending/sold
    private var activeAssets: [Asset] {
        allAssets.filter { $0.listing != .notListed }
    }

    private var filtered: [Asset] {
        activeAssets
            .filter { $0.listing == filter }
            .sorted { ($0.listedAt ?? .distantPast) > ($1.listedAt ?? .distantPast) }
    }

    // MARK: - Stats

    private var soldThisMonth: Double {
        let cal = Calendar.current
        return allAssets
            .filter {
                $0.listing == .sold &&
                $0.soldAt.map { cal.isDate($0, equalTo: Date(), toGranularity: .month) } == true
            }
            .reduce(0) { $0 + ($1.soldPrice ?? 0) }
    }

    private var activeTotalValue: Double {
        activeAssets
            .filter { $0.listing == .ready || $0.listing == .listed || $0.listing == .pending }
            .reduce(0) { $0 + ($1.askingPrice ?? $1.estimatedValue ?? 0) }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if activeAssets.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationTitle("Listings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $assetToSell) { asset in
                ListingPrepView(asset: asset)
            }
            .sheet(item: $soldAsset) { asset in
                MarkSoldSheet(asset: asset)
            }
        }
    }

    // MARK: - Content

    private var listContent: some View {
        List {
            // Summary header
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sold this month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(soldThisMonth, format: .currency(code: "USD"))
                            .font(.title2.bold())
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Active listings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(activeTotalValue, format: .currency(code: "USD"))
                            .font(.title2.bold())
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.vertical, 4)
            }

            // Filter tabs
            Section {
                Picker("Filter", selection: $filter) {
                    ForEach([ListingStatus.ready, .listed, .pending, .sold], id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(.init())
                .padding(.vertical, 4)
            }

            // Results
            if filtered.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No \(filter.displayName) Items", systemImage: filter.icon)
                    } description: {
                        Text(emptyMessage)
                    }
                    .listRowBackground(Color.clear)
                }
            } else {
                Section("\(filtered.count) item\(filtered.count == 1 ? "" : "s")") {
                    ForEach(filtered) { asset in
                        ListingRow(asset: asset)
                            .swipeActions(edge: .trailing) {
                                if asset.listing != .sold {
                                    Button {
                                        soldAsset = asset
                                    } label: {
                                        Label("Mark Sold", systemImage: "checkmark.seal")
                                    }
                                    .tint(.green)
                                }
                                if asset.listing == .listed {
                                    Button {
                                        markPending(asset)
                                    } label: {
                                        Label("Pending", systemImage: "clock")
                                    }
                                    .tint(.orange)
                                }
                                if asset.listing != .sold {
                                    Button(role: .destructive) {
                                        unlist(asset)
                                    } label: {
                                        Label("Unlist", systemImage: "xmark.bin")
                                    }
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    assetToSell = asset
                                } label: {
                                    Label("Edit Listing", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Listings Yet", systemImage: "storefront")
        } description: {
            Text("Open any asset and tap \"Prepare Listing\" to start selling.")
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .ready:    "Items you prepare listings for appear here, ready to publish from the Collect extension."
        case .listed:   "Items you've published via the extension's Fill button show up here."
        case .pending:  "Mark items as Pending when a buyer says they're coming."
        case .sold:     "Mark items as Sold to track your earnings."
        case .notListed: ""
        }
    }

    // MARK: - Actions

    private func markPending(_ asset: Asset) {
        asset.listing = .pending
        try? modelContext.save()
        syncService.enqueue(.upsertAsset(id: asset.id))
    }

    /// Cancel/unlist — return the item to Not Listed and clear its platform flags
    /// so it disappears from the active views and the extension.
    private func unlist(_ asset: Asset) {
        asset.listing          = .notListed
        asset.listedFacebook   = false
        asset.listedCraigslist = false
        asset.listedAt         = nil
        try? modelContext.save()
        syncService.enqueue(.upsertAsset(id: asset.id))
    }
}

// MARK: - Listing Row

private struct ListingRow: View {
    let asset: Asset

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                if let data = asset.photo1Data, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.secondary.opacity(0.2)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.tertiary)
                        }
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(asset.listingTitle ?? asset.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    // Status badge
                    Label(asset.listing.displayName, systemImage: asset.listing.icon)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(asset.listing.color.opacity(0.12))
                        .foregroundStyle(asset.listing.color)
                        .clipShape(Capsule())

                    // Platform chips
                    ForEach(asset.listedMarketplaces) { mp in
                        Text(mp.shortName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Days since listed
                    if let at = asset.listedAt {
                        Text(at.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Link to the live ad
                    if let urlStr = asset.listingURL, let url = URL(string: urlStr) {
                        Link(destination: url) {
                            Label("View ad", systemImage: "arrow.up.right.square")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }

            Spacer()

            // Price
            VStack(alignment: .trailing, spacing: 2) {
                if asset.listing == .sold, let p = asset.soldPrice {
                    Text(p, format: .currency(code: "USD"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                    Text("sold")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if let p = asset.askingPrice ?? asset.estimatedValue {
                    Text(p, format: .currency(code: "USD"))
                        .font(.subheadline.weight(.semibold))
                    Text("asking")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Mark Sold Sheet

struct MarkSoldSheet: View {
    let asset: Asset
    @EnvironmentObject private var syncService: SyncService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var soldPrice: Double?
    @State private var soldOn: Marketplace = .facebook

    var body: some View {
        NavigationStack {
            Form {
                Section("Sale Details") {
                    LabeledContent("Sale Price") {
                        TextField("$0", value: $soldPrice, format: .currency(code: "USD"))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    Picker("Sold On", selection: $soldOn) {
                        ForEach(Marketplace.allCases) { mp in
                            Label(mp.shortName, systemImage: mp.icon).tag(mp)
                        }
                    }
                }
            }
            .navigationTitle("Mark as Sold")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Mark Sold") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                soldPrice = asset.askingPrice ?? asset.estimatedValue
                // Pre-select the platform the asset was listed on
                soldOn = asset.listedMarketplaces.first ?? .facebook
            }
        }
    }

    private func save() {
        asset.listing     = .sold
        asset.soldPrice   = soldPrice
        asset.soldPlatform = soldOn.rawValue
        asset.soldAt      = Date()
        try? modelContext.save()
        syncService.enqueue(.upsertAsset(id: asset.id))
        dismiss()
    }
}
