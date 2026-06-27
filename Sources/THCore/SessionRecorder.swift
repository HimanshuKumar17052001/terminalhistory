import Foundation

public final class SessionRecorder {
    public private(set) var sessionID: String = ""
    private let store: SessionStore
    private let host: String
    private var seq: Int = 0
    private var pendingOut = Data()
    private var pendingIn = Data()
    private var bytesIn: Int64 = 0
    private var bytesOut: Int64 = 0
    private var lastFlush = Date()
    private var firstInput: String?
    private var sessionDir: URL?
    private var cwdSidecar: URL?

    public init(store: SessionStore, host: String) {
        self.store = store
        self.host = host
    }

    public func start(shell: String) throws {
        let now = UInt64(Date().timeIntervalSince1970 * 1000)
        let id = ULID.generate(at: now)
        sessionID = id
        let cwd = FileManager.default.currentDirectoryPath
        try store.insertSession(Session(
            id: id, startedAt: now, endedAt: nil, shell: shell,
            cwdInitial: cwd, cwdFinal: nil, host: host, status: .active,
            exitCode: nil, pinned: false, title: nil, bytesIn: 0, bytesOut: 0
        ))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("th-\(id)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        sessionDir = dir
        cwdSidecar = dir.appendingPathComponent("cwd")
        try? "".write(to: cwdSidecar!, atomically: true, encoding: .utf8)
    }

    public func sessionDirectory() -> URL? { sessionDir }

    public func appendChild(_ data: Data, at ts: UInt64) {
        pendingOut.append(data)
        bytesOut += Int64(data.count)
        flushIfNeeded(ts: ts)
    }

    public func appendUser(_ data: Data, at ts: UInt64) {
        pendingIn.append(data)
        bytesIn += Int64(data.count)
        if firstInput == nil {
            let line = String(data: data, encoding: .utf8)?
                .split(separator: "\n").first.map(String.init) ?? ""
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { firstInput = trimmed }
        }
        flushIfNeeded(ts: ts)
    }

    public func pollCwdSidecar() throws {
        guard let url = cwdSidecar, !sessionID.isEmpty else { return }
        if let raw = try? String(contentsOf: url, encoding: .utf8) {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { try store.updateFinalCwd(sessionID, cwd: t) }
        }
    }

    private func flushIfNeeded(ts: UInt64) {
        let size = pendingOut.count + pendingIn.count
        if size >= 32 * 1024 || Date().timeIntervalSince(lastFlush) > 0.5 { flush(ts: ts) }
    }

    private func flush(ts: UInt64) {
        var events: [Event] = []
        if !pendingOut.isEmpty {
            events.append(Event(seq: nextSeq(), ts: ts, direction: .out, data: pendingOut))
            pendingOut = Data()
        }
        if !pendingIn.isEmpty {
            events.append(Event(seq: nextSeq(), ts: ts, direction: .in, data: pendingIn))
            pendingIn = Data()
        }
        if !events.isEmpty {
            try? store.appendEvents(sessionID: sessionID, events: events)
            try? store.incrementByteCounters(sessionID: sessionID, inBytes: bytesIn, outBytes: bytesOut)
            bytesIn = 0; bytesOut = 0
        }
        lastFlush = Date()
        if let t = firstInput { try? store.setTitle(sessionID, title: String(t.prefix(120))) }
    }

    private func nextSeq() -> Int { defer { seq += 1 }; return seq }

    public func finish(exitCode: Int32) throws {
        flush(ts: UInt64(Date().timeIntervalSince1970 * 1000))
        try pollCwdSidecar()
        try store.finalizeSession(sessionID, status: .exited, exitCode: exitCode)
        if let dir = sessionDir { try? FileManager.default.removeItem(at: dir) }
    }
}