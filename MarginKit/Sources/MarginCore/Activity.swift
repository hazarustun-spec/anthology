import Foundation

public struct ActivityItem: Equatable, Sendable, Identifiable {
    public var id: String { "\(noteID)#\(entry.rev)" }
    public var entry: HistoryEntry
    public var noteID: String
    public var noteTitle: String
    public var topicID: String
    public var topicTitle: String
}

extension MarginStore {
    /// History entries of all live notes, newest first.
    public func recentActivity(limit: Int = 20) throws -> [ActivityItem] {
        lock.lock(); defer { lock.unlock() }
        var items: [ActivityItem] = []
        for topic in try listTopics() {
            for (ref, _) in try loadNotes(in: topic) {
                let url = historyURL(topic: topic, noteID: ref.meta.id)
                guard let data = try? FileIO.read(url) else { continue }
                for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
                    guard let entry = try? HistoryEntry.decoder.decode(HistoryEntry.self, from: Data(line.utf8)) else { continue }
                    items.append(ActivityItem(entry: entry, noteID: ref.meta.id, noteTitle: ref.meta.title, topicID: topic.id, topicTitle: topic.title))
                }
            }
        }
        items.sort { ($0.entry.at, $0.entry.rev) > ($1.entry.at, $1.entry.rev) }
        return Array(items.prefix(limit))
    }
}
