import SwiftUI
import Photos

struct ListingPrepView: View {
    let asset: Asset
    @EnvironmentObject private var syncService: SyncService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var platform: Marketplace = .facebook
    @State private var title: String         = ""
    @State private var description: String   = ""
    @State private var price: Double?
    @State private var priceRationale: String = ""
    @State private var phase: Phase          = .idle
    @State private var showSoldSheet         = false

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
                    Text("These photos will be saved to your Photos library when you tap Copy & Open.")
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

    private var actionSection: some View {
        Section {
            Button {
                copyAndOpen()
            } label: {
                Label("Copy & Open \(platform.shortName)", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .listRowBackground(Color.clear)
            .listRowInsets(.init())
            .padding(.vertical, 4)
        } footer: {
            Text("Copies the listing to your clipboard and opens \(platform.displayName). Paste the text into the listing form.")
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

    // MARK: - Copy & Open

    private func copyAndOpen() {
        // 1. Build clipboard text
        var lines = [title, "", description]
        if let p = price {
            lines += ["", "Asking: \(p.formatted(.currency(code: "USD")))"]
        }
        UIPasteboard.general.string = lines.joined(separator: "\n")

        // 2. Save photos to camera roll (silently — best-effort)
        savePhotos()

        // 3. Persist listing state on asset
        asset.listingTitle       = title
        asset.listingDescription = description
        asset.askingPrice        = price
        asset.listedAt           = Date()
        asset.listing            = .listed
        switch platform {
        case .facebook:   asset.listedFacebook   = true
        case .craigslist: asset.listedCraigslist  = true
        }
        asset.updatedAt = Date()
        try? modelContext.save()
        syncService.enqueue(.upsertAsset(id: asset.id))

        // 4. Open platform
        platform.open()

        // 5. Dismiss
        dismiss()
    }

    private func savePhotos() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            for data in asset.photos {
                if let image = UIImage(data: data) {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                }
            }
        }
    }
}

// MARK: - Asset helper (updatedAt)
private extension Asset {
    var updatedAt: Date {
        get { collection?.capturedAt ?? Date() }  // read-only fallback; real field below
        set { }                                    // no-op — updatedAt not on Asset directly
    }
}
