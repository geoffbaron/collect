import Foundation
import SwiftData

enum CollectionStatus: String, Codable {
    case recording
    case extractingFrames
    case analyzing
    case completed
    case failed
    /// Captured but not yet analyzed — photos are saved locally awaiting AI.
    case draft
}

@Model
final class Collection {
    var id: UUID
    var promptType: String
    var customPrompt: String?
    var capturedAt: Date
    var videoFileName: String?
    var status: CollectionStatus
    var rawResponse: String?
    var room: Room?

    /// For drafts (status == .draft): the captured, downscaled JPEG frames held
    /// locally until the user runs analysis. Cleared once analyzed. Local-only —
    /// never synced, so drafts stay on the device that captured them.
    var pendingPhotos: [Data]?

    @Relationship(deleteRule: .cascade, inverse: \Asset.collection)
    var assets: [Asset]

    init(promptType: PromptType, room: Room, customPrompt: String? = nil) {
        self.id = UUID()
        self.promptType = promptType.rawValue
        self.customPrompt = customPrompt
        self.capturedAt = Date()
        self.status = .recording
        self.room = room
        self.assets = []
    }

    var prompt: PromptType {
        PromptType(rawValue: promptType) ?? .generalInventory
    }

    var isDraft: Bool { status == .draft }

    /// Reconstructs the prompt template used when this collection was captured,
    /// so a draft can be analyzed later with the right prompt.
    var template: PromptTemplate {
        let base = PromptManager.template(for: prompt)
        if prompt == .custom, let custom = customPrompt, !custom.isEmpty {
            return PromptTemplate(type: .custom, systemPrompt: base.systemPrompt, userPromptPrefix: custom)
        }
        return base
    }

    var sortedAssets: [Asset] {
        assets.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}
