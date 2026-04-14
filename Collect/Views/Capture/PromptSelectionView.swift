import SwiftUI

struct PromptSelectionView: View {
    let room: Room
    let onSelected: (PromptTemplate, Bool) -> Void
    let onCancel: () -> Void

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
                                .foregroundStyle(.blue)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(type.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Custom") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Describe what to collect…", text: $customPrompt, axis: .vertical)
                        .lineLimit(2...4)

                    Button {
                        select(type: .custom, custom: customPrompt)
                    } label: {
                        Label("Scan with Custom Prompt", systemImage: "text.cursor")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
