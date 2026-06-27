import Foundation
import Darwin

public final class PTYPair {
    public let master: Int32
    public let slave: Int32
    public init() throws {
        var m: Int32 = -1
        var s: Int32 = -1
        guard openpty(&m, &s, nil, nil, nil) == 0 else { throw PTYError.openFailed }
        self.master = m
        self.slave = s
    }
    deinit { close(master); close(slave) }
}

public enum PTYError: Error { case openFailed, forkFailed }
