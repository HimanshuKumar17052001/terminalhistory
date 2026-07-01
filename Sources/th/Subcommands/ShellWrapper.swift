import Foundation
import THCore
import Darwin

public enum ShellWrapper {
    public static func run(targetShell: String, extraArgs: [String] = []) {
        // Cycle break: if config/userShell is set to th itself, fall back to
        // a sane default rather than recursing forever.
        let resolvedShell: String
        let thPath = CommandLine.arguments.first?.replacingOccurrences(of: "-", with: "") ?? "/usr/local/bin/th"
        if targetShell == thPath || targetShell.hasSuffix("/th") {
            FileHandle.standardError.write(Data("th: refusing to wrap self (\(targetShell)); falling back to /bin/zsh\n".utf8))
            resolvedShell = "/bin/zsh"
        } else {
            resolvedShell = targetShell
        }

        let storeURL = AppSupport.url().appendingPathComponent("store.sqlite")
        let store: SessionStore
        do { store = try SessionStore(url: storeURL) }
        catch {
            FileHandle.standardError.write(Data("th: cannot open store: \(error)\n".utf8))
            PTYCapturer().runNoCapture(executable: resolvedShell, args: ["-l"] + extraArgs); return
        }
        let recorder = SessionRecorder(store: store, host: Host.current().localizedName ?? "mac")
        do { try recorder.start(shell: resolvedShell) }
        catch {
            FileHandle.standardError.write(Data("th: cannot start session: \(error)\n".utf8))
            PTYCapturer().runNoCapture(executable: resolvedShell, args: ["-l"] + extraArgs); return
        }
        let sessionDir = recorder.sessionDirectory()?.path ?? ""
        var env = ProcessInfo.processInfo.environment
        env["TH_SESSION_DIR"] = sessionDir
        env["TH_SESSION_ID"] = recorder.sessionID
        env["TH_USER_SHELL"] = resolvedShell
        let exitCode: Int32
        if isatty(STDIN_FILENO) != 0 {
            do {
                exitCode = try PTYCapturer().run(
                    executable: resolvedShell, args: ["-l"] + extraArgs, env: env,
                    onOutput: { data, ts in
                        FileHandle.standardOutput.write(data)
                        recorder.appendChild(data, at: ts)
                    },
                    onInput: {
                        var buf = [UInt8](repeating: 0, count: 1024)
                        let n = read(STDIN_FILENO, &buf, buf.count)
                        if n > 0 {
                            let d = Data(bytes: buf, count: n)
                            recorder.appendUser(d, at: UInt64(Date().timeIntervalSince1970 * 1000))
                            return d
                        }
                        return nil
                    }
                )
            } catch {
                exitCode = 1
            }
        } else {
            PTYCapturer().runNoCapture(executable: resolvedShell, args: ["-l"] + extraArgs, env: env)
            exitCode = 0
        }
        try? recorder.finish(exitCode: exitCode)
    }
}