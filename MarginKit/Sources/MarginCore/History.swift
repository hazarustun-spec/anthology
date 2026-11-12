import Foundation

public enum ChangeSource: String, Codable, Sendable {
    case claudeCode = "claude-code"
    case cowork
    case app
    case gemini
    case cursor
    case vscode
    case codex
}

public struct HistoryEntry: Codable, Equatable, Sendable {
    public var rev: Int
    public var at: Date
    public var by: ChangeSource
    public var summary: String
    public var project: String?
    /// Set when a change looks risky (e.g. "large-removal"); the app highlights it with Undo.
    public var warning: String?

    public init(rev: Int, at: Date, by: ChangeSource, summary: String, project: String?, warning: String? = nil) {
        self.rev = rev
        self.at = at
        self.by = by
        self.summary = summary
        self.project = project
        self.warning = warning
    }

    /// History keeps millisecond precision so same-second changes still sort correctly.
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            try c.encode(date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
        }
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            if let date = try? Date(s, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) { return date }
            if let date = MarginDate.parse(s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath, debugDescription: "Bad date \(s)"))
        }
        return d
    }()
}

public struct NoteRef: Equatable, Sendable {
    public var topic: Topic
    public var meta: NoteMeta
    public var fileURL: URL
}
