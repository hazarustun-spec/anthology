import Foundation
import Testing
@testable import MarginCore

struct ActivityTests {
    @Test func recentActivityNewestFirstAcrossTopics() throws {
        let store = try makeStore()
        let a = try store.resolveTopic(projectPath: "/u/Kariyer", explicitTitle: nil)
        let b = try store.resolveTopic(projectPath: "/u/Site", explicitTitle: nil)
        let n1 = try store.createNote(topicID: a.id, title: "Skills", body: "x", by: .cowork, summary: "first", project: nil)
        _ = try store.createNote(topicID: b.id, title: "Plan", body: "y", by: .claudeCode, summary: "second", project: nil)
        _ = try store.updateNote(id: n1.meta.id, baseRevision: 1, body: "z", by: .app, summary: "third", project: nil)

        let items = try store.recentActivity(limit: 2)
        #expect(items.count == 2)
        #expect(items[0].entry.summary == "third")
        #expect(items[0].topicTitle == "Kariyer")
        #expect(items[0].noteTitle == "Skills")
        #expect(items[0].noteID == n1.meta.id)
        #expect(items[1].entry.summary == "second")
    }

    @Test func activityIgnoresTrashedNotes() throws {
        let store = try makeStore()
        let t = try store.createTopic(title: "T", source: nil)
        let n = try store.createNote(topicID: t.id, title: "Gone", body: "x", by: .app, summary: "c", project: nil)
        try store.deleteNote(id: n.meta.id)
        #expect(try store.recentActivity(limit: 10).isEmpty)
    }
}

@Test func historyTimestampsKeepMillisecondsAndUTC() throws {
    let entry = HistoryEntry(rev: 1, at: Date(timeIntervalSince1970: 1_762_941_840.125), by: .app, summary: "s", project: nil)
    let json = String(decoding: try HistoryEntry.encoder.encode(entry), as: UTF8.self)
    #expect(json.contains("2025-11-12T10:04:00.125Z"))
    let back = try HistoryEntry.decoder.decode(HistoryEntry.self, from: Data(json.utf8))
    #expect(abs(back.at.timeIntervalSince1970 - 1_762_941_840.125) < 0.001)
}
