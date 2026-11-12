import Foundation
import Testing
@testable import MarginCore

struct ConflictTests {
    @Test func noConflictsOnLocalNotes() throws {
        let store = try makeStore()
        let t = try store.createTopic(title: "T", source: nil)
        let n = try store.createNote(topicID: t.id, title: "N", body: "x", by: .app, summary: "c", project: nil)
        #expect(try store.conflicts(noteID: n.meta.id).isEmpty)
        #expect(try store.notesWithConflicts().isEmpty)
    }

    @Test func noContainerOutsideApps() {
        #expect(MarginPaths.iCloudContainerID == nil)
        #expect(MarginPaths.iCloudRoot() == nil)
    }
}
