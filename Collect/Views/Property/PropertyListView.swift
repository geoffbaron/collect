import SwiftUI
import SwiftData

struct PropertyListView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var limitsService: LimitsService
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var accountService: AccountService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Property.updatedAt, order: .reverse) private var properties: [Property]
    @State private var showAddProperty = false
    @State private var newPropertyName = ""
    @State private var newPropertyAddress = ""
    @State private var showSettings = false
    @State private var showLimitAlert = false
    @State private var showListings = false
    @State private var showSearch = false

    private var atPropertyLimit: Bool {
        let max = limitsService.limits.maxProperties
        return max != -1 && userProperties.count >= max
    }

    private var userProperties: [Property] {
        properties.filter { $0.ownerID == authService.currentUserID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if userProperties.isEmpty {
                    emptyState
                } else {
                    propertyList
                }
            }
            .navigationTitle(accountService.isPropertyManager ? "Portfolio" : "Properties")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "key")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }

                // Resale marketplace is a homeowner feature — hidden for
                // property managers, who don't list tenants' belongings.
                if !accountService.isPropertyManager {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showListings = true
                        } label: {
                            Image(systemName: "storefront")
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if atPropertyLimit { showLimitAlert = true }
                        else               { showAddProperty = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showListings) {
                ListingsView()
            }
            .sheet(isPresented: $showSearch) {
                ItemSearchView(ownerID: authService.currentUserID)
            }
            .alert("Property limit reached", isPresented: $showLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your plan allows up to \(limitsService.limits.maxProperties) properties. Upgrade to Pro for unlimited properties.")
            }
            .alert("New Property", isPresented: $showAddProperty) {
                TextField("Property Name", text: $newPropertyName)
                TextField("Address (optional)", text: $newPropertyAddress)
                Button("Cancel", role: .cancel) { resetForm() }
                Button("Add") { addProperty() }
                    .disabled(newPropertyName.isEmpty)
            } message: {
                Text("Enter the name and address for the new property.")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Properties", systemImage: "building.2")
        } description: {
            Text("Add a property to start collecting room inventories.")
        } actions: {
            Button("Add Property") {
                showAddProperty = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var propertyList: some View {
        List {
            ForEach(userProperties) { property in
                NavigationLink(value: property) {
                    PropertyRow(property: property)
                }
            }
            .onDelete(perform: deleteProperties)

            Button {
                if atPropertyLimit { showLimitAlert = true }
                else               { showAddProperty = true }
            } label: {
                Label("Add Property", systemImage: atPropertyLimit ? "lock.circle" : "plus.circle")
                    .foregroundStyle(atPropertyLimit ? Color(uiColor: .secondaryLabel) : .blue)
            }
        }
        .navigationDestination(for: Property.self) { property in
            if accountService.isPropertyManager {
                PMPropertyDetailView(property: property)
            } else {
                PropertyDetailView(property: property)
            }
        }
        .navigationDestination(for: Collection.self) { collection in
            CollectionDetailView(collection: collection)
        }
        .navigationDestination(for: Asset.self) { asset in
            AssetDetailView(asset: asset)
        }
    }

    private func addProperty() {
        guard !newPropertyName.isEmpty, let userID = authService.currentUserID else { return }
        let property = Property(name: newPropertyName, address: newPropertyAddress, ownerID: userID)
        modelContext.insert(property)
        syncService.enqueue(.upsertProperty(id: property.id))
        resetForm()
    }

    private func deleteProperties(at offsets: IndexSet) {
        for index in offsets {
            let property = userProperties[index]
            syncService.enqueue(.softDeleteProperty(id: property.id))
            modelContext.delete(property)
        }
    }

    private func resetForm() {
        newPropertyName = ""
        newPropertyAddress = ""
    }
}

// MARK: - Universal item search

/// Searches every item the user owns, across all properties / floors / rooms,
/// by name, category, or description. Tapping a result opens the asset detail.
struct ItemSearchView: View {
    let ownerID: String?
    @Environment(\.dismiss) private var dismiss
    @Query private var allAssets: [Asset]
    @State private var query = ""

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [Asset] {
        let q = trimmedQuery.lowercased()
        guard !q.isEmpty else { return [] }
        return allAssets
            .filter { $0.collection?.room?.floor?.property?.ownerID == ownerID }
            .filter {
                $0.name.lowercased().contains(q)
                || $0.category.lowercased().contains(q)
                || $0.assetDescription.lowercased().contains(q)
            }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Group {
                if trimmedQuery.isEmpty {
                    ContentUnavailableView(
                        "Search Items",
                        systemImage: "magnifyingglass",
                        description: Text("Find any item across all your properties by name, category, or description.")
                    )
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(results) { asset in
                        NavigationLink(value: asset) {
                            LocatedAssetRow(asset: asset)
                        }
                    }
                }
            }
            .navigationTitle("Search Items")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Asset.self) { asset in
                AssetDetailView(asset: asset)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Name, category, or description"
            )
        }
    }
}

/// An AssetRow with the item's location path shown underneath — used in search
/// results where items come from many different rooms.
struct LocatedAssetRow: View {
    let asset: Asset

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            AssetRow(asset: asset)
            if let path = asset.collection?.room?.locationPath {
                Label(path, systemImage: "mappin.and.ellipse")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct PropertyRow: View {
    let property: Property

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(property.name)
                .font(.headline)

            if !property.address.isEmpty {
                Text(property.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Label("\(property.floors.count) floors", systemImage: "square.stack.3d.up")
                Label("\(property.totalRooms) rooms", systemImage: "door.left.hand.open")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
