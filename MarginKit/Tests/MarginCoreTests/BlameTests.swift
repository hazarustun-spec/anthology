import Foundation
import Testing
@testable import MarginCore

struct BlameTests {
    @Test func attributesEachLineToTheChangeThatAddedIt() throws {
        let store = try makeStore()
        let t = try store.createTopic(title: "T", source: nil)
        let n = try store.createNote(topicID: t.id, title: "Skills", body: "- SQL\n- Go", by: .cowork, summary: "c", project: nil)
        _ = try store.updateNote(id: n.meta.id, baseRevision: 1, body: "- SQL\n- Go\n- Rust", by: .app, summary: "u", project: nil)
        _ = try store.updateNote(id: n.meta.id, baseRevision: 2, body: "- SQL (done)\n- Go\n- Rust", by: .claudeCode, summary: "u2", project: nil)

        let blame = try store.lineAttribution(noteID: n.meta.id)
        #expect(blame.map(\.text) == ["- SQL (done)", "- Go", "- Rust"])
        #expect(blame.map(\.source) == [.claudeCode, .cowork, .app])
        #expect(blame.map(\.revision) == [3, 1, 2])
    }

    @Test func movedAndUnchangedLinesKeepTheirAuthor() throws {
        let store = try makeStore()
        let t = try store.createTopic(title: "T", source: nil)
        let n = try store.createNote(topicID: t.id, title: "N", body: "a\nb\nc", by: .cursor, summary: "c", project: nil)
        _ = try store.updateNote(id: n.meta.id, baseRevision: 1, body: "new\na\nb\nc", by: .app, summary: "u", project: nil)
        let blame = try store.lineAttribution(noteID: n.meta.id)
        #expect(blame.map(\.source) == [.app, .cursor, .cursor, .cursor])
    }

    @Test func notesWithoutHistoryFallBackToCurrentRevision() throws {
        let store = try makeStore()
        let t = try store.createTopic(title: "T", source: nil)
        let url = store.root.appendingPathComponent("\(t.directoryName)/plain.md")
        try "x\ny".write(to: url, atomically: true, encoding: .utf8)
        let id = try store.listNotes(topicID: t.id)[0].meta.id
        let blame = try store.lineAttribution(noteID: id)
        #expect(blame.count == 2)
        #expect(blame.allSatisfy { $0.source == nil })
    }
}
