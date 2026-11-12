import Foundation

public struct Topic: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    /// Project folders (absolute paths as reported by Claude) that route to this topic.
    public var sources: [String]
    public var createdAt: Date
    public var sortOrder: Int
    /// SF Symbol name chosen in the app (nil = default folder).
    public var icon: String?
    /// Palette color name chosen in the app (nil = default).
    public var color: String?
    /// On-disk directory name (`<slug>-<4 hex>`). Fixed at creation; not stored in `_topic.json`.
    public var directoryName: String = ""

    enum CodingKeys: String, CodingKey { case id, title, sources, createdAt, sortOrder, icon, color }

    public init(id: String, title: String, sources: [String], createdAt: Date, sortOrder: Int, directoryName: String) {
        self.id = id
        self.title = title
        self.sources = sources
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.directoryName = directoryName
    }
}
