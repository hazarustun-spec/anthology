import Foundation

public enum ChangeSource: String, Codable, Sendable {
    case claudeCode = "claude-code"
    case cowork
    case app
}

public struct HistoryEntry: Codable, Equatable, Sendable {
    public var rev: Int
    public var at: Date
    public var by: ChangeSource
    public var summary: String
    public var project: String?
}

public struct NoteRef: Equatable, Sendable {
    public var topic: Topic
    public var meta: NoteMeta
    public var fileURL: URL
}
