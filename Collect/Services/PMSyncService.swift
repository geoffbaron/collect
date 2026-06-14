import Foundation
import Network
import Supabase

/// A queued write against a PM table. Operations carry their full payload
/// (rather than a reference to a local object) since PM entities aren't
/// persisted locally — there's nothing to re-fetch when draining later.
enum PMSyncOperation: Codable, Hashable {
    case insert(table: String, localID: String, payload: [String: AnyJSON])
    case update(table: String, id: String, payload: [String: AnyJSON])
    case softDelete(table: String, id: String)

    var table: String {
        switch self {
        case .insert(let table, _, _):  return table
        case .update(let table, _, _):  return table
        case .softDelete(let table, _): return table
        }
    }

    /// The id this operation targets — the client-generated id for inserts.
    var recordID: String {
        switch self {
        case .insert(_, let localID, _): return localID
        case .update(_, let id, _):      return id
        case .softDelete(_, let id):     return id
        }
    }
}

/// Queues PM-mode writes (create/update/status-change/delete) made while
/// offline, persists them across launches, and drains them once connectivity
/// returns. Mirrors `SyncService`'s queue/drain/retry shape, but operates on
/// raw `[String: AnyJSON]` payloads since PM entities are plain structs with
/// no local store to read back from.
///
/// Exposed as a singleton so the plain PM services (WorkOrderService,
/// UnitService, etc.) can enqueue without threading a dependency through
/// every initializer, while also being usable as an `@EnvironmentObject` for
/// the sync status badge.
@MainActor
final class PMSyncService: ObservableObject {

    static let shared = PMSyncService()

    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var syncState: SyncState = .idle

    private var queue: [PMSyncOperation] = [] {
        didSet { pendingCount = queue.count }
    }
    private var isDraining = false
    private var isOnline = true
    private var pathMonitor: NWPathMonitor?
    private let queueKey = "collect_pm_sync_queue"
    private let db = SupabaseManager.shared.client

    private init() {
        loadQueue()
    }

    func configure() {
        startNetworkMonitor()
        Task { await drain() }
    }

    func reset() {
        queue.removeAll()
        saveQueue()
        pathMonitor?.cancel()
        pathMonitor = nil
        syncState = .idle
    }

    // MARK: - Enqueue

    /// Adds an operation to the queue, merging it into a still-pending
    /// `.insert` for the same record where possible (the row doesn't exist
    /// server-side yet, so there's nothing to separately update/delete).
    func enqueue(_ operation: PMSyncOperation) {
        switch operation {
        case .insert:
            queue.append(operation)

        case .update(let table, let id, let payload):
            if let idx = pendingInsertIndex(table: table, localID: id) {
                if case .insert(let t, let localID, var existing) = queue[idx] {
                    for (key, value) in payload { existing[key] = value }
                    queue[idx] = .insert(table: t, localID: localID, payload: existing)
                    saveQueue()
                    return
                }
            }
            queue.append(operation)

        case .softDelete(let table, let id):
            if let idx = pendingInsertIndex(table: table, localID: id) {
                // The row never made it to the server — drop the insert and
                // any update queued against it.
                queue.remove(at: idx)
                queue.removeAll { op in
                    if case .update(let t, let opID, _) = op, t == table, opID == id { return true }
                    return false
                }
                saveQueue()
                return
            }
            queue.append(operation)
        }

        saveQueue()
        Task { await drain() }
    }

    private func pendingInsertIndex(table: String, localID: String) -> Int? {
        queue.firstIndex { op in
            if case .insert(let t, let id, _) = op, t == table, id == localID { return true }
            return false
        }
    }

    func forceDrain() {
        Task { await drain() }
    }

    // MARK: - Drain

    func drain() async {
        guard !isDraining, !queue.isEmpty, isOnline else { return }

        isDraining = true
        syncState = .syncing
        defer {
            isDraining = false
            syncState = queue.isEmpty ? .idle : syncState
        }

        var processed: [PMSyncOperation] = []
        for operation in queue {
            do {
                try await process(operation)
                processed.append(operation)
            } catch {
                print("PMSyncService: operation failed — \(error)")
                syncState = .error("Sync failed: \(error.localizedDescription)")
                break
            }
        }

        queue.removeAll { processed.contains($0) }
        saveQueue()

        if queue.isEmpty { syncState = .idle }
    }

    private func process(_ op: PMSyncOperation) async throws {
        switch op {
        case .insert(let table, let localID, var payload):
            payload["id"] = .string(localID)
            try await db.from(table).insert(payload).execute()

        case .update(let table, let id, let payload):
            try await db.from(table).update(payload).eq("id", value: id).execute()

        case .softDelete(let table, let id):
            let iso = ISO8601DateFormatter().string(from: Date())
            try await db.from(table).update(["deleted_at": iso]).eq("id", value: id).execute()
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
        monitor.start(queue: DispatchQueue(label: "com.collect.pmsync.network"))
    }

    // MARK: - Queue persistence

    private func saveQueue() {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
    }

    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: queueKey),
              let saved = try? JSONDecoder().decode([PMSyncOperation].self, from: data) else { return }
        queue = saved
    }
}
