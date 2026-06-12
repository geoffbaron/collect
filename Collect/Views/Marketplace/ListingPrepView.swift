import SwiftUI

struct ListingPrepView: View {
    let asset: Asset
    @EnvironmentObject private var syncService:    SyncService
    @EnvironmentObject private var authService:    AuthService
    @EnvironmentObject private var featuresService: FeaturesService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var platform: Marketplace = .facebook
    @State private var title: String         = ""
    @State private var description: String   = ""
    @State private var price: Double?
    @State private var priceRationale: String = ""
    @State private var phase: Phase          = .idle
    @State private var showReady             = false

    enum Phase { case idle, generating, ready, error(String) }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                platformSection
                switch phase {
                case .idle:
                    generateSection
                case .generating:
                    generatingSection
                case .ready:
                    draftSection
                    actionSection
                case .error(let msg):
                    errorSection(msg)
                }
            }
            .navigationTitle("Prepare Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await generate() }
        .sheet(isPresented: $showReady, onDismiss: { dismiss() }) {
            ListingReadySheet(platform: platform)
        }
    }

    // MARK: - Sections

    private var platformSection: some View {
        Section {
            Picker("Platform", selection: $platform) {
                ForEach(Marketplace.allCases) { mp in
                    Label(mp.shortName, systemImage: mp.icon).tag(mp)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(.init())
            .padding(.vertical, 4)
            .onChange(of: platform) { _, _ in
                Task { await generate() }
            }
        }
    }

    private var generateSection: some View {
        Section {
            HStack {
                Spacer()
                Button("Generate Listing") {
                    Task { await generate() }
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
        } footer: {
            Text("AI will write a \(platform.shortName)-optimised listing using your asset photos and details.")
        }
    }

    private var generatingSection: some View {
        Section {
            HStack(spacing: 12) {
                ProgressView().controlSize(.regular)
                Text("Writing \(platform.shortName) listing…")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var draftSection: some View {
        Group {
            // Photo thumbnails
            if !asset.photos.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(asset.photos.indices, id: \.self) { i in
                                if let img = UIImage(data: asset.photos[i]) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    Text("These photos sync with your listing and appear in the Collect extension.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Photos")
                }
            }

            Section("Title") {
                TextField("Title", text: $title, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Description") {
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(4...10)
            }

            Section {
                LabeledContent("Asking Price") {
                    TextField("$0", value: $price, format: .currency(code: "USD"))
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                }
                if !priceRationale.isEmpty {
                    Text(priceRationale)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Price")
            } footer: {
                Text("Edit any field before copying — AI suggestions are a starting point.")
            }

            Section {
                Button("Regenerate") {
                    Task { await generate() }
                }
                .foregroundStyle(.blue)
            }
        }
    }

    @ViewBuilder private var actionSection: some View {
        Section {
            Button {
                saveForExtension()
            } label: {
                Label("Make Available in Extension", systemImage: "puzzlepiece.extension.fill")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .listRowBackground(Color.clear)
            .listRowInsets(.init())
            .padding(.vertical, 4)
        } footer: {
            Text("Saves and syncs this listing so you can publish it to \(platform.displayName) from the Collect Chrome extension on your computer.")
        }
    }

    private func errorSection(_ message: String) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Generation failed", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Try Again") {
                    Task { await generate() }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Generate

    private func generate() async {
        phase = .generating
        title = ""
        description = ""
        price = nil
        priceRationale = ""

        do {
            let draft = try await ListingService.shared.generate(asset: asset, platform: platform)
            title          = draft.title
            description    = draft.description
            price          = draft.suggestedPrice ?? asset.askingPrice ?? asset.estimatedValue
            priceRationale = draft.priceRationale
            phase          = .ready
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    // MARK: - Save for extension

    /// Persists the listing and syncs it (photos included) so the Collect Chrome
    /// extension can pick it up and publish it. Publishing itself happens entirely
    /// in the extension — the app no longer opens the marketplace or copies text.
    private func saveForExtension() {
        // 1. Persist listing state on the asset. Status is "ready" — prepared and
        // synced, visible in the extension, but not counted as "listed" until the
        // user actually posts it via Fill in the extension.
        asset.listingTitle       = title
        asset.listingDescription = description
        asset.askingPrice        = price
        asset.listedAt           = Date()
        asset.listing            = .ready
        switch platform {
        case .facebook:   asset.listedFacebook   = true
        case .craigslist: asset.listedCraigslist  = true
        }
        try? modelContext.save()

        // 2. Upload immediately so the extension can access the listing + photos
        // right away. If the immediate upload fails (e.g. transient network
        // error), fall back to the durable sync queue so the listing still
        // reaches Supabase — and the extension — on the next drain.
        if featuresService.cloudStorageEnabled, let userID = authService.currentUserID {
            Task {
                do {
                    try await CloudRepository.shared.upsert(
                        asset: asset, userID: userID, uploadPhotos: true
                    )
                } catch {
                    syncService.enqueue(.upsertAsset(id: asset.id))
                }
            }
        } else {
            syncService.enqueue(.upsertAsset(id: asset.id))
        }

        // 3. Confirm it's ready in the extension (dismisses prep view on close)
        showReady = true
    }
}

// MARK: - Listing Ready Sheet

/// Shown after a listing is saved & synced — confirms it's ready to publish from
/// the Collect Chrome extension. Publishing happens entirely in the extension.
struct ListingReadySheet: View {
    let platform: Marketplace
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Success icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)
                }
                .padding(.top, 16)

                VStack(spacing: 10) {
                    Text("Listing Ready")
                        .font(.title2.bold())

                    Text("Your \(platform.displayName) listing is saved and synced. Open the Collect extension in Chrome on your computer to review and publish it — title, description, price, and photos are already filled in.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Reassurance row
                HStack(spacing: 12) {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                    Text("Make sure you're signed in to the extension with this same account.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)

                Spacer()

                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
