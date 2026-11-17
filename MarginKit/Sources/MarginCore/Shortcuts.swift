import Foundation

/// User-configurable chat shortcuts, shared by the app, anthology-mcp and the Claude Code hook.
public struct MarginSettings: Codable, Equatable, Sendable {
    /// `//m <text>`: Claude files it into the right note, no confirmation.
    public var smartPrefix: String
    /// `//m! <text>`: saved verbatim to the folder's quick-notes note; with the hook it never reaches Claude.
    public var instantPrefix: String
    /// Whether AI tools may move notes to the trash (off by default: a hijacked model can't delete).
    public var allowDelete: Bool
    /// Whether AI tools may move notes between topics.
    public var allowMove: Bool

    public static let `default` = MarginSettings(smartPrefix: "//m", instantPrefix: "//m!")

    public init(smartPrefix: String, instantPrefix: String, allowDelete: Bool = false, allowMove: Bool = true) {
        self.smartPrefix = smartPrefix
        self.instantPrefix = instantPrefix
        self.allowDelete = allowDelete
        self.allowMove = allowMove
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        smartPrefix = try c.decodeIfPresent(String.self, forKey: .smartPrefix) ?? Self.default.smartPrefix
        instantPrefix = try c.decodeIfPresent(String.self, forKey: .instantPrefix) ?? Self.default.instantPrefix
        allowDelete = try c.decodeIfPresent(Bool.self, forKey: .allowDelete) ?? false
        allowMove = try c.decodeIfPresent(Bool.self, forKey: .allowMove) ?? true
    }

    public static var defaultURL: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/Anthology/settings.json")
    }

    public static func load(from url: URL = defaultURL) -> MarginSettings {
        guard let data = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(MarginSettings.self, from: data) else { return .default }
        return s.sanitized()
    }

    public func save(to url: URL = defaultURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try e.encode(sanitized()).write(to: url, options: .atomic)
    }

    /// Prefixes must be non-empty, without whitespace, at most 8 characters, and different from each other.
    public func sanitized() -> MarginSettings {
        func ok(_ p: String) -> Bool { !p.isEmpty && p.count <= 8 && !p.contains(where: \.isWhitespace) }
        guard ok(smartPrefix), ok(instantPrefix), smartPrefix != instantPrefix else {
            return MarginSettings(smartPrefix: Self.default.smartPrefix, instantPrefix: Self.default.instantPrefix, allowDelete: allowDelete, allowMove: allowMove)
        }
        return self
    }

    public enum PromptKind: Equatable, Sendable {
        case none
        case smart(String)
        case instant(String)
    }

    /// Classifies a chat message. The prefix must be followed by whitespace and some text.
    public func classify(_ prompt: String) -> PromptKind {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        // Check the longer prefix first so "//m!" is not read as "//m" + "!…".
        let ordered: [(String, (String) -> PromptKind)] = [(instantPrefix, { .instant($0) }), (smartPrefix, { .smart($0) })]
            .sorted { $0.0.count > $1.0.count }
        for (prefix, make) in ordered where trimmed.hasPrefix(prefix) {
            let rest = trimmed.dropFirst(prefix.count)
            guard let first = rest.first, first.isWhitespace else { continue }
            let text = rest.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? .none : make(text)
        }
        return .none
    }
}

extension MarginStore {
    /// Appends a timestamped line to the quick-notes note of the folder's topic (created on first use).
    @discardableResult
    public func quickCapture(_ text: String, projectPath: String?, by: ChangeSource, noteTitle: String) throws -> NoteRef {
        try beginWrite(); defer { endWrite() }
        let topic = try resolveTopic(projectPath: projectPath, explicitTitle: nil)
        return try quickCapture(text, topicID: topic.id, by: by, noteTitle: noteTitle, project: projectPath)
    }

    @discardableResult
    public func quickCapture(_ text: String, topicID: String, by: ChangeSource, noteTitle: String, project projectPath: String? = nil) throws -> NoteRef {
        try beginWrite(); defer { endWrite() }
        let topic = try self.topic(id: topicID)
        let stamp = Date().formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        let line = "- \(stamp) · \(text.replacingOccurrences(of: "\n", with: " "))"
        let summary = String(text.prefix(60))
        if let (ref, file) = try findNote(topicID: topic.id, title: noteTitle) {
            let body = file.body.isEmpty || file.body.hasSuffix("\n") ? file.body + line : file.body + "\n" + line
            return try updateNote(id: ref.meta.id, baseRevision: ref.meta.revision, body: body, by: by, summary: summary, project: projectPath)
        }
        return try createNote(topicID: topic.id, title: noteTitle, body: line, by: by, summary: summary, project: projectPath)
    }
}

/// Claude Code `UserPromptSubmit` hook: instant captures never reach the model; smart ones get a nudge.
public struct HookHandler: Sendable {
    let store: MarginStore
    let settings: MarginSettings
    let quickNoteTitle: String
    let markerDirectory: URL

    public init(store: MarginStore, settings: MarginSettings, quickNoteTitle: String,
                markerDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("anthology-hook", isDirectory: true)) {
        self.store = store
        self.settings = settings
        self.quickNoteTitle = quickNoteTitle
        self.markerDirectory = markerDirectory
    }

    /// The hook can be registered twice (the app's settings.json entry and the Claude Code plugin).
    /// Only the first invocation for a given prompt acts; the second lets the prompt through untouched.
    func claimPrompt(_ key: String) -> Bool {
        let fm = FileManager.default
        try? fm.createDirectory(at: markerDirectory, withIntermediateDirectories: true)
        // Forget markers older than a minute.
        for name in (try? fm.contentsOfDirectory(atPath: markerDirectory.path)) ?? [] {
            let url = markerDirectory.appendingPathComponent(name)
            if let date = (try? fm.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date,
               Date().timeIntervalSince(date) > 60 { try? fm.removeItem(at: url) }
        }
        var hash: UInt64 = 0xcbf29ce484222325 // FNV-1a
        for byte in key.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        let path = markerDirectory.appendingPathComponent(String(hash, radix: 16)).path
        let fd = open(path, O_CREAT | O_EXCL | O_WRONLY, 0o600)
        guard fd >= 0 else { return errno != EEXIST }
        close(fd)
        return true
    }

    /// Returns the hook's JSON output, or nil to let the prompt through untouched.
    public func handle(_ input: Data) -> Data? {
        guard let object = try? JSONSerialization.jsonObject(with: input) as? [String: Any],
              let prompt = object["prompt"] as? String else { return nil }
        let cwd = (object["cwd"] as? String).flatMap(MarginTools.usableProjectPath)
        let kind = settings.classify(prompt)
        if case .none = kind { return nil }
        guard claimPrompt("\(object["session_id"] as? String ?? "")\u{0}\(prompt)") else {
            // Another hook instance (or a quick resend) already handled this prompt. An instant capture must
            // still never reach the model, so block it without saving a second copy.
            if case .instant = kind { return json(["decision": "block", "reason": "✓ Anthology"]) }
            return nil
        }
        switch kind {
        case .none:
            return nil
        case .instant(let text):
            do {
                let ref = try store.quickCapture(text, projectPath: cwd, by: .claudeCode, noteTitle: quickNoteTitle)
                return json(["decision": "block", "reason": "✓ Anthology: \(ref.topic.title) › \(ref.meta.title)"])
            } catch {
                return json(["decision": "block", "reason": "Anthology couldn't save this: \(error.localizedDescription)"])
            }
        case .smart:
            let context = "The user started this message with the Anthology shortcut \(settings.smartPrefix). "
                + "Save the rest of the message to Anthology now, without asking for confirmation: pick or update the right note "
                + "(project_path: \(Self.quoted(cwd))), then reply with one short line saying where it went."
            return json(["hookSpecificOutput": ["hookEventName": "UserPromptSubmit", "additionalContext": context]])
        }
    }

    /// Folder paths go into model context; keep them on one line and clearly delimited.
    static func quoted(_ path: String?) -> String {
        guard let path else { return "unknown" }
        let flat = path.components(separatedBy: .newlines).joined(separator: " ").replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(flat.prefix(1024))\""
    }

    private func json(_ object: [String: Any]) -> Data? {
        try? JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes])
    }
}

#if os(macOS)
/// Adds/removes Anthology's `UserPromptSubmit` hook in Claude Code's `~/.claude/settings.json`, leaving other hooks alone.
public enum ClaudeHookConfig {
    static let event = "UserPromptSubmit"

    public static var userSettings: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude/settings.json")
    }

    static func isOurs(_ group: [String: Any]) -> Bool {
        ((group["hooks"] as? [[String: Any]]) ?? []).contains { ($0["command"] as? String)?.hasSuffix("anthology-mcp\" hook") == true || ($0["command"] as? String)?.hasSuffix("anthology-mcp hook") == true }
    }

    public static func isInstalled(at url: URL = userSettings, command: String) -> Bool {
        guard let root = try? MCPConfigFile.read(url),
              let groups = (root["hooks"] as? [String: Any])?[event] as? [[String: Any]] else { return false }
        return groups.contains { (($0["hooks"] as? [[String: Any]]) ?? []).contains { $0["command"] as? String == command } }
    }

    public static func install(at link: URL = userSettings, command: String) throws {
        let url = link.resolvingSymlinksInPath()
        var root = FileManager.default.fileExists(atPath: url.path) ? try MCPConfigFile.read(url) : [:]
        try MCPConfigFile.backup(url)
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        var groups = (hooks[event] as? [[String: Any]] ?? []).filter { !isOurs($0) }
        groups.append(["hooks": [["type": "command", "command": command, "timeout": 10]]])
        hooks[event] = groups
        root["hooks"] = hooks
        try MCPConfigFile.write(root, to: url)
    }

    public static func remove(at link: URL = userSettings) throws {
        let url = link.resolvingSymlinksInPath()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        var root = try MCPConfigFile.read(url)
        guard var hooks = root["hooks"] as? [String: Any], let groups = hooks[event] as? [[String: Any]] else { return }
        try MCPConfigFile.backup(url)
        hooks[event] = groups.filter { !isOurs($0) }
        root["hooks"] = hooks
        try MCPConfigFile.write(root, to: url)
    }
}

#endif
