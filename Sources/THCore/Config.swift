import Foundation

public enum IconVariant: String, Codable { case auto, light, dark, monochrome }

public struct ThemeConfig: Codable, Equatable {
    public var iconVariant: IconVariant
    public var accentHex: String
    public init(iconVariant: IconVariant = .auto, accentHex: String = "system") {
        self.iconVariant = iconVariant
        self.accentHex = accentHex
    }
}

public struct Config: Codable, Equatable {
    public var userShell: String?
    public var previousShell: String?
    public var defaultTerminal: String?
    public var retention: RetentionPolicy
    public var theme: ThemeConfig
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
        self.userShell = nil
        self.previousShell = nil
        self.defaultTerminal = nil
        self.retention = .default
        self.theme = ThemeConfig()
        load()
    }

    private func configURL() -> URL { directory.appendingPathComponent("config.json") }

    public func save() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(self)
        try data.write(to: configURL(), options: .atomic)
    }

    private mutating func load() {
        guard let data = try? Data(contentsOf: configURL()),
              let decoded = try? JSONDecoder().decode(Config.self, from: data) else { return }
        self = decoded
    }
}