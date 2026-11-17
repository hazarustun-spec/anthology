import Foundation
import Testing
@testable import MarginCore

struct TopicTests {
    @Test func slugTurkish() {
        #expect(slugify("Kazanmak İstediğim Şeyler") == "kazanmak-istedigim-seyler")
        #expect(slugify("  !!  ") == "topic")
        #expect(slugify("Çağrı Öğüt") == "cagri-ogut")
    }

    @Test func missingRootCreated() throws {
        let root = tempRoot().appendingPathComponent("nested/deeper")
        let store = try MarginStore(root: root)
        #expect(try store.listTopics() == [])
        #expect(FileManager.default.fileExists(atPath: root.path))
    }

    @Test func defaultRootHonorsEnv() {
        let url = MarginPaths.defaultRoot(env: ["MARGIN_ROOT": "/tmp/x-margin"])
        #expect(url.path == "/tmp/x-margin")
    }

    @Test func resolveCreatesFromFolder() throws {
        let store = try makeStore()
        let topic = try store.resolveTopic(projectPath: "/Users/x/Kariyer", explicitTitle: nil)
        #expect(topic.title == "Kariyer")
        #expect(topic.directoryName.wholeMatch(of: /kariyer-[0-9a-f]{4}/) != nil)
        #expect(try store.listTopics().count == 1)
    }

    @Test func prettifiesFolderNames() throws {
        let store = try makeStore()
        #expect(try store.resolveTopic(projectPath: "/u/career-notes", explicitTitle: nil).title == "Career notes")
        #expect(try store.resolveTopic(projectPath: "/u/my_side_project/", explicitTitle: nil).title == "My side project")
    }

    @Test func emptyPathGoesToInbox() throws {
        let store = try makeStore()
        #expect(try store.resolveTopic(projectPath: nil, explicitTitle: nil).title == "Inbox")
        #expect(try store.resolveTopic(projectPath: "", explicitTitle: nil).title == "Inbox")
        #expect(try store.listTopics().count == 1)
    }

    @Test func renameKeepsRouting() throws {
        let store = try makeStore()
        let first = try store.resolveTopic(projectPath: "/Users/x/Kariyer", explicitTitle: nil)
        _ = try store.renameTopic(id: first.id, title: "Career")
        let again = try store.resolveTopic(projectPath: "/Users/x/Kariyer", explicitTitle: nil)
        #expect(again.id == first.id)
        #expect(again.title == "Career")
        #expect(again.directoryName == first.directoryName)
    }

    @Test func basenameFallbackAddsSource() throws {
        let store = try makeStore()
        let first = try store.resolveTopic(projectPath: "/Users/x/Kariyer", explicitTitle: nil)
        let second = try store.resolveTopic(projectPath: "/sessions/abc/mnt/Kariyer", explicitTitle: nil)
        #expect(second.id == first.id)
        #expect(Set(second.sources) == ["/Users/x/Kariyer", "/sessions/abc/mnt/Kariyer"])
    }

    @Test func ambiguousBasename() throws {
        let store = try makeStore()
        let a = try store.resolveTopic(projectPath: "/a/Notes", explicitTitle: nil)
        _ = try store.createTopic(title: "Other notes", source: "/b/Notes")
        #expect(throws: MarginError.self) {
            try store.resolveTopic(projectPath: "/c/Notes", explicitTitle: nil)
        }
        #expect(try store.resolveTopic(projectPath: "/a/Notes", explicitTitle: nil).id == a.id)
    }

    @Test func explicitTitleWins() throws {
        let store = try makeStore()
        let r1 = try store.resolveTopic(projectPath: "/u/Kariyer", explicitTitle: "Reading")
        let r2 = try store.resolveTopic(projectPath: "/u/Other", explicitTitle: "reading")
        #expect(r1.title == "Reading")
        #expect(r1.id == r2.id)
        #expect(try store.listTopics().count == 1)
    }

    @Test func trashTopicRemovesItAndItsNotes() throws {
        let store = try makeStore()
        let topic = try store.resolveTopic(projectPath: "/u/Old", explicitTitle: nil)
        _ = try store.createNote(topicID: topic.id, title: "N", body: "x", by: .app, summary: "s", project: nil)
        try store.trashTopic(id: topic.id, systemTrash: false)
        #expect(try store.listTopics().isEmpty)
        #expect(FileManager.default.fileExists(atPath: store.root.appendingPathComponent(".trash/\(topic.directoryName)").path))
        // A later save from the same folder starts a fresh topic.
        #expect(try store.resolveTopic(projectPath: "/u/Old", explicitTitle: nil).id != topic.id)
    }
}
