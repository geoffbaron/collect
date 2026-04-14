import SwiftUI
import SwiftData

struct ResultsView: View {
    let room: Room
    let template: PromptTemplate
    let scanResult: ScanResult
    let videoURL: URL
    let capturedLayout: RoomLayout?
    let onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @StateObject private var locationService = LocationService.shared
    @State private var items: [AssetResult]
    @State private var saved = false

    init(room: Room, template: PromptTemplate, scanResult: ScanResult, videoURL: URL, capturedLayout: RoomLayout? = nil, onSaved: @escaping () -> Void) {
        self.room = room
        self.template = template
        self.scanResult = scanResult
        self.videoURL = videoURL
        self.capturedLayout = capturedLayout
        self.onSaved = onSaved
        self._items = State(initialValue: scanResult.assets)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Label(template.type.displayName, systemImage: template.type.icon)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(items.count) items")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach($items) { $item in
                    AssetEditRow(item: $item)
                }
                .onDelete { items.remove(atOffsets: $0) }
            } header: {
                HStack {
                    Text("Review & Edit")
                    Spacer()
                    let total = items.reduce(0.0) { sum, item in
                        sum + (item.estimatedValue ?? 0) * Double(item.quantity)
                    }
                    if total > 0 {
                        Text("Total: \(total, format: .currency(code: "USD"))")
                            .textCase(nil)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
            } footer: {
                Text("Swipe left to remove an item. Tap to expand and edit.")
            }
        }
        .navigationTitle("Results")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    save()
                } label: {
                    Text("Save All")
                        .fontWeight(.semibold)
                }
                .disabled(items.isEmpty || saved)
            }
        }
        .overlay {
            if saved {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.green)
                    Text("Saved!")
                        .font(.title.bold())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: saved)
        .onAppear { locationService.requestPermissionAndStart() }
        .onDisappear { locationService.stopUpdating() }
    }

    private func save() {
        let collection = Collection(promptType: template.type, room: room)
        collection.status = .completed
        modelContext.insert(collection)

        let lat = locationService.coordinate?.latitude
        let lon = locationService.coordinate?.longitude
        let frames = scanResult.selectedFrames

        // Save freshly scanned layout to room (if one was captured in this session)
        if let newLayout = capturedLayout {
            room.layoutData = newLayout.toData()
        }

        // Match assets to RoomPlan placed objects if a layout is available
        let layout = capturedLayout ?? room.layoutData.flatMap { RoomLayout.from($0) }
        let assetPairs = items.map { (name: $0.name, category: $0.category) }
        let positionMap = layout?.matchAssets(assetPairs) ?? [:]

        for (idx, item) in items.enumerated() {
            let asset = Asset(
                name: item.name,
                category: item.category,
                assetDescription: item.description,
                condition: item.condition,
                quantity: item.quantity,
                confidence: item.confidence,
                collection: collection
            )
            asset.isConfirmed = true
            asset.estimatedValue = item.estimatedValue
            asset.latitude    = lat
            asset.longitude   = lon
            // Pin to floor plan position if matched
            if let placed = positionMap[idx] {
                asset.layoutX = placed.centerX
                asset.layoutZ = placed.centerZ
            }
            // Insert first — @Attribute(.externalStorage) requires the object
            // to be in the context before binary data is written to disk
            modelContext.insert(asset)
            // Per-asset photos: use the frame indices Gemini identified for this specific asset
            if let idx1 = item.frameIndices.first, idx1 < frames.count {
                asset.photo1Data = frames[idx1].jpegData(compressionQuality: 0.8)
            }
            if item.frameIndices.count > 1 {
                let idx2 = item.frameIndices[1]
                if idx2 < frames.count {
                    asset.photo2Data = frames[idx2].jpegData(compressionQuality: 0.8)
                }
            }
        }

        try? modelContext.save()
        try? FileManager.default.removeItem(at: videoURL)
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { onSaved() }
    }
}

// MARK: - Editable row

struct AssetEditRow: View {
    @Binding var item: AssetResult
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        HStack(spacing: 6) {
                            Text(item.category)
                                .font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                            if let cond = item.condition {
                                Text(cond).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if let val = item.estimatedValue {
                            Text(val, format: .currency(code: "USD"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        Text("×\(item.quantity)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider().padding(.top, 8)
                    LabeledContent("Name") {
                        TextField("Name", text: $item.name).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Category") {
                        TextField("Category", text: $item.category).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Qty") {
                        Stepper("\(item.quantity)", value: $item.quantity, in: 1...99)
                    }
                    LabeledContent("Value") {
                        TextField("$0", value: $item.estimatedValue, format: .currency(code: "USD"))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    if !item.description.isEmpty {
                        Text(item.description).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}
