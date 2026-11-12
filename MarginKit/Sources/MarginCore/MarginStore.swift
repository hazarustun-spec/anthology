import Foundation

/// File-backed store for topics and notes. All writes go through `FileIO` (coordinated, atomic).
public final class MarginStore: @unchecked Sendable {
    public let root: URL
    let lock = NSRecursiveLock()
    private var writeDepth = 0
    private var lockFD: Int32 = -1
    /// How long a write waits for another process's lock before failing.
    public var lockTimeout: TimeInterval = 8

    static let topicFile = "_topic.json"
    static let reservedDirectories: Set<String> = [".trash", ".history"]

    public init(root: URL) throws {
        self.root = root.standardizedFileURL
        try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
    }

    // MARK: Topics

    public func listTopics() throws -> [Topic] {
        lock.lock(); defer { lock.unlock() }
        let entries = try FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        )
        var topics: [Topic] = []
        for dir in entries where (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            let file = dir.appendingPathComponent(Self.topicFile)
            guard let data = try? FileIO.read(file), var topic = try? Self.decoder.decode(Topic.self, from: data) else { continue }
            topic.directoryName = dir.lastPathComponent
            topics.append(topic)
        }
        return topics.sorted {
            ($0.sortOrder, $0.title.localizedLowercase) < ($1.sortOrder, $1.title.localizedLowercase)
        }
    }

    public func topic(id: String) throws -> Topic {
        guard let topic = try listTopics().first(where: { $0.id == id }) else { throw MarginError.topicNotFound(id) }
        return topic
    }

    @discardableResult
    public func createTopic(title: String, source: String?) throws -> Topic {
        try beginWrite(); defer { endWrite() }
        let existing = try listTopics()
        var dirName: String
        repeat {
            dirName = "\(slugify(title))-\(String(format: "%04x", Int.random(in: 0..<0x10000)))"
        } while FileManager.default.fileExists(atPath: root.appendingPathComponent(dirName).path)
        let topic = Topic(
            id: newID(),
            title: singleLine(title),
            sources: source.map { [$0] } ?? [],
            createdAt: MarginDate.now(),
            sortOrder: (existing.map(\.sortOrder).max() ?? -1) + 1,
            directoryName: dirName
        )
        try save(topic)
        return topic
    }

    public func renameTopic(id: String, title: String) throws -> Topic {
        try beginWrite(); defer { endWrite() }
        var topic = try self.topic(id: id)
        topic.title = singleLine(title)
        try save(topic)
        return topic
    }

    public func addSource(topicID: String, source: String) throws {
        try beginWrite(); defer { endWrite() }
        var topic = try self.topic(id: topicID)
        guard !topic.sources.contains(source) else { return }
        topic.sources.append(source)
        try save(topic)
    }

    /// Finds or creates the topic for a save. See spec §6.2 for the lookup order.
    public func resolveTopic(projectPath: String?, explicitTitle: String?) throws -> Topic {
        try beginWrite(); defer { endWrite() }
        let topics = try listTopics()

        if let title = explicitTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            if let match = topics.first(where: { $0.title.compare(title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
                return match
            }
            return try createTopic(title: title, source: nil)
        }

        let path = Self.normalize(projectPath)
        guard let path else {
            return try topics.first(where: { $0.title == "Inbox" }) ?? createTopic(title: "Inbox", source: nil)
        }

        if let exact = topics.first(where: { $0.sources.contains(path) }) { return exact }

        let base = (path as NSString).lastPathComponent
        let byBase = topics.filter { t in
            t.sources.contains { ($0 as NSString).lastPathComponent.caseInsensitiveCompare(base) == .orderedSame }
        }
        if byBase.count == 1 {
            try addSource(topicID: byBase[0].id, source: path)
            return try topic(id: byBase[0].id)
        }
        if byBase.count > 1 { throw MarginError.ambiguousTopic(byBase.map(\.title)) }

        return try createTopic(title: prettifyFolderName(base), source: path)
    }

    // MARK: Cross-process write lock

    /// Serializes mutations across processes (every Claude session runs its own margin-mcp, plus the app).
    /// Reentrant within this process. Pair with `endWrite()` via `defer`.
    func beginWrite() throws {
        lock.lock()
        writeDepth += 1
        guard writeDepth == 1 else { return }
        let path = root.appendingPathComponent(".margin.lock").path
        lockFD = open(path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard lockFD >= 0 else { return }
        let deadline = Date().addingTimeInterval(lockTimeout)
        while flock(lockFD, LOCK_EX | LOCK_NB) != 0 {
            if Date() >= deadline {
                close(lockFD)
                lockFD = -1
                writeDepth -= 1
                lock.unlock()
                throw MarginError.busy
            }
            usleep(50_000)
        }
    }

    func endWrite() {
        writeDepth -= 1
        if writeDepth == 0, lockFD >= 0 {
            flock(lockFD, LOCK_UN)
            close(lockFD)
            lockFD = -1
        }
        lock.unlock()
    }

    // MARK: Helpers

    func directory(of topic: Topic) -> URL {
        root.appendingPathComponent(topic.directoryName, isDirectory: true)
    }

    func save(_ topic: Topic) throws {
        let data = try Self.encoder.encode(topic)
        try FileIO.write(data, to: directory(of: topic).appendingPathComponent(Self.topicFile))
    }

    static func normalize(_ path: String?) -> String? {
        guard var p = path?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty else { return nil }
        while p.count > 1, p.hasSuffix("/") { p.removeLast() }
        return p
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
