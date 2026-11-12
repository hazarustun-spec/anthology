import Foundation
import Testing
@testable import MarginCore

struct NoteStoreTests {
    private func setup() throws -> (MarginStore, Topic) {
        let store = try makeStore()
        let topic = try store.resolveTopic(projectPath: "/u/Kariyer", explicitTitle: nil)
        return (store, topic)
    }

    @Test func createAndRead() throws {
        let (store, topic) = try setup()
        let ref = try store.createNote(topicID: topic.id, title: "Skills", body: "- SQL", by: .claudeCode, summary: "Created", project: "/u/Kariyer")
        let (found, file) = try store.findNote(id: ref.meta.id)
        #expect(file.body == "- SQL")
        #expect(found.meta.revision == 1)
        let history = try store.history(noteID: ref.meta.id)
        #expect(history.count == 1)
        #expect(history[0].by == .claudeCode)
        #expect(history[0].project == "/u/Kariyer")
    }

    @Test func updateIncrementsAndLogs() throws {
        let (store, topic) = try setup()
        let ref = try store.createNote(topicID: topic.id, title: "Skills", body: "- SQL", by: .claudeCode, summary: "Created", project: nil)
        let updated = try store.updateNote(id: ref.meta.id, baseRevision: 1, body: "- SQL\n- Go", by: .cowork, summary: "Added Go", project: nil)
        #expect(updated.meta.revision == 2)
        #expect(try store.history(noteID: ref.meta.id).last?.summary == "Added Go")
        #expect(try store.history(noteID: ref.meta.id).last?.rev == 2)
    }

    @Test func staleUpdateRejected() throws {
        let (store, topic) = try setup()
        let ref = try store.createNote(topicID: topic.id, title: "Skills", body: "v1", by: .app, summary: "c", project: nil)
        _ = try store.updateNote(id: ref.meta.id, baseRevision: 1, body: "first", by: .app, summary: "u1", project: nil)
        #expect(throws: MarginError.staleRevision(expected: 1, actual: 2)) {
            try store.updateNote(id: ref.meta.id, baseRevision: 1, body: "second", by: .claudeCode, summary: "u2", project: nil)
        }
        #expect(try store.findNote(id: ref.meta.id).1.body == "first")
    }

    @Test func appendKeepsExisting() throws {
        let (store, topic) = try setup()
        let ref = try store.createNote(topicID: topic.id, title: "Skills", body: "- SQL", by: .app, summary: "c", project: nil)
        let appended = try store.appendToNote(id: ref.meta.id, text: "- Go", by: .claudeCode, summary: "a", project: nil)
        #expect(appended.meta.revision == 2)
        #expect(try store.findNote(id: ref.meta.id).1.body == "- SQL\n\n- Go")
    }

    @Test func filenameCollision() throws {
        let (store, topic) = try setup()
        let a = try store.createNote(topicID: topic.id, title: "Plan", body: "a", by: .app, summary: "c", project: nil)
        let b = try store.createNote(topicID: topic.id, title: "Plan", body: "b", by: .app, summary: "c", project: nil)
        #expect(a.fileURL.lastPathComponent == "plan.md")
        #expect(b.fileURL.lastPathComponent == "plan-2.md")
    }

    @Test func findByTitleCaseInsensitive() throws {
        let (store, topic) = try setup()
        let ref = try store.createNote(topicID: topic.id, title: "Kazanmak istediğim skiller", body: "x", by: .app, summary: "c", project: nil)
        #expect(try store.findNote(topicID: topic.id, title: "kazanmak İSTEDİĞİM skiller")?.0.meta.id == ref.meta.id)
        #expect(try store.findNote(topicID: topic.id, title: "nope") == nil)
    }

    @Test func deleteMovesToTrash() throws {
        let (store, topic) = try setup()
        let ref = try store.createNote(topicID: topic.id, title: "Gone", body: "x", by: .app, summary: "c", project: nil)
        try store.deleteNote(id: ref.meta.id)
        #expect(!FileManager.default.fileExists(atPath: ref.fileURL.path))
        let trashed = store.root.appendingPathComponent(".trash/\(topic.directoryName)/gone.md")
        #expect(FileManager.default.fileExists(atPath: trashed.path))
        #expect(try store.listNotes(topicID: topic.id).isEmpty)
    }

    @Test func moveNote() throws {
        let (store, topic) = try setup()
        let other = try store.createTopic(title: "Reading", source: nil)
        let ref = try store.createNote(topicID: topic.id, title: "Books", body: "x", by: .app, summary: "c", project: nil)
        let moved = try store.moveNote(id: ref.meta.id, toTopicID: other.id)
        #expect(moved.topic.id == other.id)
        #expect(try store.listNotes(topicID: topic.id).isEmpty)
        #expect(try store.history(noteID: ref.meta.id).count == 1)
    }

    @Test func searchDiacritics() throws {
        let (store, topic) = try setup()
        _ = try store.createNote(topicID: topic.id, title: "Skills", body: "- Sistem tasarımı", by: .app, summary: "c", project: nil)
        #expect(try store.search("tasarimi").count == 1)
        #expect(try store.search("TASARIMI").count == 1)
        #expect(try store.search("skills").count == 1)
        #expect(try store.search("kotlin").isEmpty)
    }

    @Test func listTopicsIgnoresTrashAndHistory() throws {
        let (store, topic) = try setup()
        let ref = try store.createNote(topicID: topic.id, title: "Gone", body: "x", by: .app, summary: "c", project: nil)
        try store.deleteNote(id: ref.meta.id)
        #expect(try store.listTopics().map(\.id) == [topic.id])
        #expect(try store.listNotes(topicID: topic.id).isEmpty)
    }
}
