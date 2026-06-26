import Foundation
import Darwin

@_silgen_name("fork")
private func sysFork() -> Int32

public final class PTYCapturer {
    public init() {}

    public func run(
        executable: String,
        args: [String],
        env: [String: String]? = nil,
        cwd: String? = nil,
        windowSize: winsize = winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0),
        onOutput: @escaping (Data, UInt64) -> Void,
        onInput: (() -> Data?)? = nil
    ) throws -> Int32 {
        let pair = try PTYPair()
        var ws = windowSize
        _ = ioctl(pair.master, TIOCSWINSZ, &ws)

        let pid = sysFork()
        if pid == 0 {
            close(pair.master)
            setsid()
            if let cwd { _ = cwd.withCString { chdir($0) } }
            _ = ioctl(pair.slave, TIOCSCTTY, 0)
            dup2(pair.slave, 0); dup2(pair.slave, 1); dup2(pair.slave, 2)
            close(pair.slave)
            if let env { for (k, v) in env { setenv(k, v, 1) } }
            let argv = ([executable] + args).map { strdup($0) } + [nil]
            execvp(executable, argv)
            exit(127)
        }
        if pid < 0 { throw PTYError.forkFailed }
        close(pair.slave)

        let queue = DispatchQueue(label: "th.pty", qos: .userInitiated)
        let group = DispatchGroup()
        let stop = ManagedBool(false)

        group.enter()
        queue.async {
            var buf = [UInt8](repeating: 0, count: 4096)
            while !stop.get() {
                let n = read(pair.master, &buf, buf.count)
                if n > 0 { onOutput(Data(bytes: buf, count: n), UInt64(Date().timeIntervalSince1970 * 1000)) }
                else if n == 0 || (n < 0 && errno != EAGAIN) { break }
            }
            group.leave()
        }
        if let onInput {
            queue.async {
                var buf = [UInt8](repeating: 0, count: 1024)
                while !stop.get() {
                    if let d = onInput(), !d.isEmpty {
                        d.withUnsafeBytes { raw in
                            if let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) {
                                _ = Darwin.write(pair.master, base, d.count)
                            }
                        }
                    } else if read(STDIN_FILENO, &buf, buf.count) <= 0 {
                        break
                    }
                }
            }
        }

        var status: Int32 = 0
        waitpid(pid, &status, 0)
        stop.set(true)
        close(pair.master)
        group.wait()
        if (status & 0x7f) == 0 { return (status >> 8) & 0xff }
        return 128 + (status & 0x7f)
    }

    public func runNoCapture(executable: String, args: [String], env: [String: String]? = nil) -> Int32 {
        let pair = try? PTYPair()
        let pid = sysFork()
        if pid == 0 {
            if let p = pair { close(p.master); _ = ioctl(p.slave, TIOCSCTTY, 0); dup2(p.slave, 0); dup2(p.slave, 1); dup2(p.slave, 2); close(p.slave) }
            if let env { for (k, v) in env { setenv(k, v, 1) } }
            let argv = ([executable] + args).map { strdup($0) } + [nil]
            execvp(executable, argv)
            exit(127)
        }
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        if let p = pair { close(p.master) }
        if (status & 0x7f) == 0 { return (status >> 8) & 0xff }
        return 128 + (status & 0x7f)
    }
}

private final class ManagedBool {
    private var v: Bool
    private let lock = NSLock()
    init(_ x: Bool) { v = x }
    func get() -> Bool { lock.lock(); defer { lock.unlock() }; return v }
    func set(_ x: Bool) { lock.lock(); v = x; lock.unlock() }
}
