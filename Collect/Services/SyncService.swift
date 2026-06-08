import Foundation
import SwiftUI
import SwiftData
import Network

// MARK: - Operation types

enum SyncOperation: Codable, Hashable {
    case upsertProperty(id: UUID)
    case upsertFloor(id: UUID)
    case upsertRoom(id: UUID)
    case upsertCollection(id: UUID)
    case upsertAsset(id: UUID)
    case softDeleteProperty(id: UUID)
    case softDeleteFloor(id: UUID)
    case softDeleteRoom(id: UUID)
    case softDeleteCollection(id: UUID)
    case softDeleteAsset(id: UUID)

    var entityID: UUID {
        switch self {
        case .upsertProperty(let id),    .softDeleteProperty(let id):    return id
        case .upsertFloor(let id),       .softDeleteFloor(let id):       return id
        case .upsertRoom(let id),        .softDeleteRoom(let id):        return id
        case .upsertCollection(let id),  .softDeleteCollection(let id):  return id
        case .upsertAsset(let id),       .softDeleteAsset(let id):       return id
        }
    }
}

// MARK: - Sync state

enum SyncState: Equatable {
    case idle
    case syncing
    case error(String)
}

// MARK: - Service

@MainActor
final class SyncService: ObservableObject {

    @Published var syncState: SyncState = .idle

    /// Set by FeaturesService after auth — controls photo uploads during drain
    var cloudStorageEnabled = false

    /// Injected from ContentView.task so we can fetch objects during drain
    var modelContext: ModelContext?

    // MARK: - Private state

    private var queue: [SyncOperation] = []
    private var isDraining = false
    private var userID: String?
    private var pathMonitor: NWPathMonitor?
    private var isOnline = true
    private let queueKey = "collect_sync_queue"

    // MARK: - Setup

    func configure(userID: String) {
        self.userID = userID
        loadQueue()
        startNetworkMonitor()
        Task { await drain() }
    }

    func reset() {
        userID = nil
        queue.removeAll()
        saveQueue()
        pathMonitor?.cancel()
        pathMonitor = nil
        syncState = .idle
    }

    // MARK: - Enqueue

    func enqueue(_ operation: SyncOperation) {
        // Deduplicate: a later upsert supersedes an earlier one for the same entity
        queue.removeAll { $0 == operation }
        // A soft-delete cancels any pending upsert for the same entity
        let entityID = operation.entityID
        switch operation {
        case .softDeleteProperty, .softDeleteFloor, .softDeleteRoom,
             .softDeleteCollection, .softDeleteAsset:
            queue.removeAll { $0.entityID == entityID }
        default:
            break
        }
        queue.append(operation)
        saveQueue()
        Task { await drain() }
    }

    func forceDrain() {
        Task { await drain() }
    }

    // MARK: - Drain

    func drain() async {
        guard !isDraining,
              !queue.isEmpty,
              isOnline,
              let userID,
              let context = modelContext else { return }

        isDraining = true
        syncState = .syncing
        defer {
            isDraining = false
            syncState = queue.isEmpty ? .idle : syncState
        }

        var processed: [SyncOperation] = []

        for operation in queue {
            do {
                try await process(operation, userID: userID, context: context)
                processed.append(operation)
            } catch {
                // Network / server error — leave in queue, stop draining
                print("SyncService: operation failed — \(error)")
                syncState = .error("Sync failed: \(error.localizedDescription)")
                break
            }
        }

        queue.removeAll { processed.contains($0) }
        saveQueue()

        if queue.isEmpty { syncState = .idle }
    }

    // MARK: - Process individual operations

    private func process(_ op: SyncOperation, userID: String, context: ModelContext) async throws {
        let repo = CloudRepository.shared
        switch op {
        case .upsertProperty(let id):
            if let obj = try context.fetch(FetchDescriptor<Property>(predicate: #Predicate { $0.id == id })).first {
                try await repo.upsert(property: obj, userID: userID)
            }
        case .upsertFloor(let id):
            if let obj = try context.fetch(FetchDescriptor<Floor>(predicate: #Predicate { $0.id == id })).first {
                try await repo.upsert(floor: obj, userID: userID)
            }
        case .upsertRoom(let id):
            if let obj = try context.fetch(FetchDescriptor<Room>(predicate: #Predicate { $0.id == id })).first {
                try await repo.upsert(room: obj, userID: userID)
            }
        case .upsertCollection(let id):
            if let obj = try context.fetch(FetchDescriptor<Collection>(predicate: #Predicate { $0.id == id })).first {
                try await repo.upsert(collection: obj, userID: userID)
            }
        case .upsertAsset(let id):
            if let obj = try context.fetch(FetchDescriptor<Asset>(predicate: #Predicate { $0.id == id })).first {
                try await repo.upsert(asset: obj, userID: userID, uploadPhotos: cloudStorageEnabled)
            }
        case .softDeleteProperty(let id):
            try await repo.softDelete(table: "properties", id: id)
        case .softDeleteFloor(let id):
            try await repo.softDelete(table: "floors", id: id)
        case .softDeleteRoom(let id):
            try await repo.softDelete(table: "rooms", id: id)
        case .softDeleteCollection(let id):
            try await repo.softDelete(table: "collections", id: id)
        case .softDeleteAsset(let id):
            try await repo.softDelete(table: "assets", id: id)
        }
    }

    // MARK: - Network monitor

    private func startNetworkMonitor() {
        pathMonitor?.cancel()
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let nowOnline = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = nowOnline
                if wasOffline && nowOnline {
                    await self.drain()
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.collect.sync.network"))
    }

    // MARK: - Queue persistence

    private func saveQueue() {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
    }

    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: queueKey),
              let saved = try? JSONDecoder().decode([SyncOperation].self, from: data) else { return }
        queue = saved
    }
}
