import Foundation
import SwiftData

enum CollectionStatus: String, Codable {
    case recording
    case extractingFrames
    case analyzing
    case completed
    case failed
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

    var sortedAssets: [Asset] {
        assets.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}
