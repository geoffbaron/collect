import SwiftUI

struct PromptSelectionView: View {
    let room: Room
    let onSelected: (PromptTemplate, Bool) -> Void
    let onCancel: () -> Void

    @EnvironmentObject private var limitsService: LimitsService
    @State private var customPrompt = ""
    @State private var includeLayoutScan: Bool

    init(room: Room, onSelected: @escaping (PromptTemplate, Bool) -> Void, onCancel: @escaping () -> Void) {
        self.room = room
        self.onSelected = onSelected
        self.onCancel = onCancel
        // Default ON when the room has no layout yet
        self._includeLayoutScan = State(initialValue: room.layoutData == nil)
    }

    var body: some View {
        List {
            // ── Quota banner ──────────────────────────────────────────────
            Section {
                HStack(spacing: 10) {
                    if limitsService.canScan {
                        Image(systemName: "camera.viewfinder")
                            .foregroundStyle(.blue)
                        Text(limitsService.usageLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "lock.circle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Monthly limit reached")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Upgrade to Pro for unlimited scans.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Text("What would you like to collect in \(room.name)?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init())
            }

            Section {
                Toggle(isOn: $includeLayoutScan) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Map Room Layout")
                                .font(.headline)
                            Text(room.layoutData == nil
                                 ? "Scan with LiDAR before collecting assets"
                                 : "Rescan to update existing floor plan")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "map")
                            .foregroundStyle(.blue)
                    }
                }
            } footer: {
                Text("Requires a device with LiDAR. Walk around the room slowly for best results.")
            }

            Section("Scan Types") {
                ForEach(PromptType.allCases.filter { $0 != .custom }) { type in
                    Button {
                        select(type: type, custom: nil)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: type.icon)
                                .font(.title2)
                                .foregroundStyle(limitsService.canScan ? .blue : .secondary)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.displayName)
                                    .font(.headline)
                                    .foregroundStyle(limitsService.canScan ? .primary : .secondary)
                                Text(type.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: limitsService.canScan ? "chevron.right" : "lock")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(!limitsService.canScan)
                }
            }

            Section("Custom") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Describe what to collect…", text: $customPrompt, axis: .vertical)
                        .lineLimit(2...4)
                        .disabled(!limitsService.canScan)

                    Button {
                        select(type: .custom, custom: customPrompt)
                    } label: {
                        Label("Scan with Custom Prompt", systemImage: "text.cursor")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!limitsService.canScan || customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Scan Room")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
        }
        .onAppear {
            Task { await limitsService.refreshUsage() }
        }
    }

    private func select(type: PromptType, custom: String?) {
        var template = PromptManager.template(for: type)
        if let custom, type == .custom {
            template = PromptTemplate(
                type: .custom,
                systemPrompt: template.systemPrompt,
                userPromptPrefix: custom
            )
        }
        onSelected(template, includeLayoutScan)
    }
}
