import SwiftUI

/// Shown after analysis when AI detects possible duplicate assets.
/// User can merge items into one entry (with combined quantity) or keep them separate.
struct GroupReviewView: View {
    /// The full result set — we show duplicates here, pass everything through to Results.
    @State private var items: [AssetResult]
    let scanResult: ScanResult
    let onContinue: ([AssetResult]) -> Void

    // Groups that still need a decision
    private var pendingGroups: [[AssetResult]] {
        var byTag: [String: [AssetResult]] = [:]
        for asset in items where asset.groupingHint == .possibleDuplicate {
            let tag = asset.duplicateGroup ?? asset.name.lowercased()
            byTag[tag, default: []].append(asset)
        }
        return byTag.values.filter { $0.count >= 2 }.sorted { $0[0].name < $1[0].name }
    }

    init(scanResult: ScanResult, onContinue: @escaping ([AssetResult]) -> Void) {
        self.scanResult = scanResult
        self._items = State(initialValue: scanResult.assets)
        self.onContinue = onContinue
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "square.on.square.badge.person.crop")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Review Possible Duplicates")
                            .font(.headline)
                        Text("AI spotted items that look identical. Merge them into one entry or keep them as separate records.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if pendingGroups.isEmpty {
                Section {
                    Label("All groups resolved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            } else {
                ForEach(pendingGroups, id: \.first!.duplicateGroup) { group in
                    DuplicateGroupCard(
                        group: group,
                        frames: scanResult.selectedFrames,
                        onMerge: { merge(group: group) },
                        onKeepSeparate: { keepSeparate(group: group) }
                    )
                }
            }
        }
        .navigationTitle("Duplicates Found")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Continue") {
                    onContinue(items)
                }
                .fontWeight(.semibold)
                .disabled(!pendingGroups.isEmpty)
            }
        }
    }

    // MARK: - Actions

    /// Collapse all items in the group into a single entry with summed quantity.
    private func merge(group: [AssetResult]) {
        guard let first = group.first else { return }
        let totalQty = group.reduce(0) { $0 + $1.quantity }
        let tag = first.duplicateGroup ?? first.name.lowercased()

        // Build merged item
        var merged = first
        merged.quantity = totalQty
        merged.groupingHint = .consolidated
        merged.duplicateGroup = nil

        // Remove all items in this group, insert merged one in place of the first
        let ids = Set(group.map { $0.id })
        items.removeAll { ids.contains($0.id) }

        // Insert at the position the first item occupied (or append if gone)
        items.append(merged)
        _ = tag // suppress unused warning
    }

    /// Mark items as unique so they pass through as individual records.
    private func keepSeparate(group: [AssetResult]) {
        let ids = Set(group.map { $0.id })
        for idx in items.indices where ids.contains(items[idx].id) {
            items[idx].groupingHint = .unique
            items[idx].duplicateGroup = nil
        }
    }
}

// MARK: - Group card

private struct DuplicateGroupCard: View {
    let group: [AssetResult]
    let frames: [UIImage]
    let onMerge: () -> Void
    let onKeepSeparate: () -> Void

    var body: some View {
        Section {
            // Preview thumbnails
            if !frames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(group) { asset in
                            if let frameIdx = asset.frameIndices.first,
                               frameIdx < frames.count {
                                Image(uiImage: frames[frameIdx])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            // Item list
            ForEach(group) { asset in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(asset.name).font(.subheadline.weight(.medium))
                        if let cond = asset.condition {
                            Text(cond).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let val = asset.estimatedValue {
                        Text(val, format: .currency(code: "USD"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    onMerge()
                } label: {
                    Label("Merge ×\(group.reduce(0) { $0 + $1.quantity })", systemImage: "arrow.triangle.merge")
                        .frame(maxWidth: .infinity)
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button {
                    onKeepSeparate()
                } label: {
                    Label("Keep Separate", systemImage: "square.split.2x1")
                        .frame(maxWidth: .infinity)
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        } header: {
            HStack {
                Text(group.first?.name ?? "")
                Spacer()
                Text("\(group.count) found")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}
