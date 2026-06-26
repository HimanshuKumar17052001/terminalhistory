import Foundation

public struct RetentionPolicy: Equatable {
    public var maxAgeDays: Int
    public var maxBytes: Int64
    public init(maxAgeDays: Int, maxBytes: Int64) {
        self.maxAgeDays = maxAgeDays
        self.maxBytes = maxBytes
    }
    public static let `default` = RetentionPolicy(maxAgeDays: 90, maxBytes: 5 * 1024 * 1024 * 1024)
}

public struct RetentionResult: Equatable {
    public var deleted: [String]
    public var remainingBytes: Int64
}

public final class Retention {
    private let store: SessionStore
    private let policy: RetentionPolicy
    public init(store: SessionStore, policy: RetentionPolicy) {
        self.store = store
        self.policy = policy
    }
    public func prune() throws -> RetentionResult {
        var deleted: [String] = []
        let now = UInt64(Date().timeIntervalSince1970 * 1000)
        let ageCutoff = now - UInt64(policy.maxAgeDays) * 86_400_000
        let ageIds = try store.sessionIds(olderThan: ageCutoff, pinned: false)
        if !ageIds.isEmpty {
            try store.deleteSessions(ids: ageIds)
            deleted.append(contentsOf: ageIds)
        }
        var size = try store.totalSizeBytes()
        if size > policy.maxBytes {
            let extras = try store.oldestUnpinnedSessions(excluding: Set(deleted), limit: 500)
            for id in extras {
                if size <= policy.maxBytes { break }
                try store.deleteSessions(ids: [id])
                deleted.append(id)
                size = try store.totalSizeBytes()
            }
        }
        return RetentionResult(deleted: deleted, remainingBytes: size)
    }
}