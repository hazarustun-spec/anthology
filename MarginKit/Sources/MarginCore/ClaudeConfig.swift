import Foundation

/// Edits the `mcpServers` section of a Claude config file (Claude Desktop's
/// `claude_desktop_config.json` or Claude Code's `~/.claude.json`) without touching anything else.
public enum MCPConfigFile {
    public static let serverName = "margin"

    public enum Status: Equatable, Sendable {
        case connected, notConnected, differentBinary, unreadable
    }

    public enum ConfigError: Error, LocalizedError {
        case malformed(String)
        public var errorDescription: String? {
            switch self {
            case .malformed(let path): "This config file isn't valid JSON, so Margin left it untouched: \(path)"
            }
        }
    }

    public static func status(at url: URL, binary: String) -> Status {
        guard FileManager.default.fileExists(atPath: url.path) else { return .notConnected }
        guard let root = try? read(url) else { return .unreadable }
        guard let entry = (root["mcpServers"] as? [String: Any])?[serverName] as? [String: Any] else { return .notConnected }
        return entry["command"] as? String == binary ? .connected : .differentBinary
    }

    /// Adds or replaces the `margin` server. Backs the file up first; refuses to touch malformed JSON.
    public static func install(at url: URL, entry: [String: Any]) throws {
        var root = FileManager.default.fileExists(atPath: url.path) ? try read(url) : [:]
        try backup(url)
        var servers = root["mcpServers"] as? [String: Any] ?? [:]
        servers[serverName] = entry
        root["mcpServers"] = servers
        try write(root, to: url)
    }

    public static func remove(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        var root = try read(url)
        guard var servers = root["mcpServers"] as? [String: Any], servers[serverName] != nil else { return }
        try backup(url)
        servers[serverName] = nil
        root["mcpServers"] = servers
        try write(root, to: url)
    }

    static func read(_ url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        if data.isEmpty { return [:] }
        guard let object = try? JSONSerialization.jsonObject(with: data), let dict = object as? [String: Any] else {
            throw ConfigError.malformed(url.path)
        }
        return dict
    }

    static func write(_ root: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: url, options: .atomic)
    }

    static func backup(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)).replacingOccurrences(of: ":", with: "")
        let dest = url.deletingLastPathComponent().appendingPathComponent("\(url.lastPathComponent).margin-backup-\(stamp)")
        if !FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.copyItem(at: url, to: dest)
        }
    }
}

/// Where Claude's config files and Margin's installed helper live.
public enum ClaudePaths {
    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }
    public static var desktopConfig: URL { home.appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json") }
    public static var claudeCodeConfig: URL { home.appendingPathComponent(".claude.json") }
    public static var installedHelper: URL { home.appendingPathComponent("Library/Application Support/Margin/bin/margin-mcp") }

    /// The `claude` CLI: PATH-style locations first, then the copy Claude Desktop ships.
    public static func claudeCLI() -> URL? {
        let fm = FileManager.default
        let candidates = ["/opt/homebrew/bin/claude", "/usr/local/bin/claude", "\(home.path)/.local/bin/claude", "\(home.path)/.claude/local/claude"]
        if let hit = candidates.first(where: { fm.isExecutableFile(atPath: $0) }) { return URL(fileURLWithPath: hit) }
        let bundled = home.appendingPathComponent("Library/Application Support/Claude/claude-code")
        let versions = ((try? fm.contentsOfDirectory(atPath: bundled.path)) ?? []).sorted { $0.compare($1, options: .numeric) == .orderedDescending }
        for version in versions {
            let dir = bundled.appendingPathComponent(version)
            for sub in (try? fm.contentsOfDirectory(atPath: dir.path)) ?? [] {
                let exe = dir.appendingPathComponent("\(sub)/claude.app/Contents/MacOS/claude")
                if fm.isExecutableFile(atPath: exe.path) { return exe }
            }
        }
        return nil
    }
}
