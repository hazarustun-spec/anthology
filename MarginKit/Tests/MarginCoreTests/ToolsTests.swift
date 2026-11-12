import Foundation
import Testing
@testable import MarginCore

struct ToolsTests {
    private func tools() throws -> (MarginTools, MarginStore) {
        let store = try makeStore()
        return (MarginTools(store: store, source: .claudeCode), store)
    }

    @Test func toolSpecsComplete() {
        #expect(Set(MarginTools.toolSpecs.map(\.name)) == [
            "list_topics", "get_note", "search_notes", "save_note",
            "update_note", "rename_topic", "move_note", "delete_note", "quick_capture",
        ])
    }

    @Test func saveCreatesThenAppends() throws {
        let (tools, store) = try tools()
        let args: [String: ToolArg] = [
            "content": .string("- SQL"), "summary": .string("x"),
            "project_path": .string("/u/Kariyer"), "note_title": .string("Skills"),
        ]
        let first = tools.call("save_note", args)
        #expect(!first.isError)
        #expect(first.text.contains("Kariyer › Skills"))
        var second = args
        second["content"] = .string("- Go")
        #expect(!tools.call("save_note", second).isError)

        let topic = try store.listTopics()[0]
        let notes = try store.listNotes(topicID: topic.id)
        #expect(notes.count == 1)
        let body = try store.findNote(id: notes[0].meta.id).1.body
        #expect(body.contains("- SQL") && body.contains("- Go"))
    }

    @Test func saveWithoutTitleUsesFirstLine() throws {
        let (tools, store) = try tools()
        let r = tools.call("save_note", ["content": .string("# Reading list\n- Dune"), "summary": .string("s"), "topic": .string("Books")])
        #expect(!r.isError)
        let topic = try store.listTopics()[0]
        #expect(topic.title == "Books")
        #expect(try store.listNotes(topicID: topic.id)[0].meta.title == "Reading list")
    }

    @Test func getNoteShowsRevision() throws {
        let (tools, store) = try tools()
        _ = tools.call("save_note", ["content": .string("- SQL"), "summary": .string("s"), "project_path": .string("/u/Kariyer"), "note_title": .string("Skills")])
        let id = try store.listNotes(topicID: store.listTopics()[0].id)[0].meta.id
        let byID = tools.call("get_note", ["note_id": .string(id)])
        #expect(byID.text.contains("revision=1"))
        #expect(byID.text.contains("- SQL"))
        let byTitle = tools.call("get_note", ["topic": .string("Kariyer"), "title": .string("skills")])
        #expect(byTitle.text.contains("note_id=\(id)"))
    }

    @Test func updateStaleIsError() throws {
        let (tools, store) = try tools()
        _ = tools.call("save_note", ["content": .string("a"), "summary": .string("s"), "note_title": .string("N"), "topic": .string("T")])
        let id = try store.listNotes(topicID: store.listTopics()[0].id)[0].meta.id
        let ok = tools.call("update_note", ["note_id": .string(id), "base_revision": .int(1), "content": .string("b"), "summary": .string("u")])
        #expect(!ok.isError)
        let stale = tools.call("update_note", ["note_id": .string(id), "base_revision": .int(1), "content": .string("c"), "summary": .string("u")])
        #expect(stale.isError)
        #expect(stale.text.contains("Call get_note again"))
    }

    @Test func ambiguousIsError() throws {
        let (tools, store) = try tools()
        _ = try store.createTopic(title: "Work notes", source: "/a/Notes")
        _ = try store.createTopic(title: "Home notes", source: "/b/Notes")
        let r = tools.call("save_note", ["content": .string("x"), "summary": .string("s"), "project_path": .string("/c/Notes")])
        #expect(r.isError)
        #expect(r.text.contains("Work notes") && r.text.contains("Home notes"))
    }

    @Test func missingRequiredArg() throws {
        let (tools, _) = try tools()
        let r = tools.call("save_note", ["summary": .string("s")])
        #expect(r.isError)
        #expect(r.text.contains("content"))
    }

    @Test func listAndSearch() throws {
        let (tools, _) = try tools()
        _ = tools.call("save_note", ["content": .string("- Sistem tasarımı"), "summary": .string("s"), "project_path": .string("/u/Kariyer"), "note_title": .string("Skills")])
        #expect(tools.call("list_topics", [:]).text.contains("Kariyer"))
        #expect(tools.call("search_notes", ["query": .string("tasarimi")]).text.contains("Skills"))
        #expect(tools.call("list_topics", [:]).isError == false)
    }

    @Test func instructionsMentionConsent() {
        #expect(MarginTools.serverInstructions.contains("project_path"))
        #expect(MarginTools.serverInstructions.localizedCaseInsensitiveContains("consent"))
    }
}

struct DefaultProjectTests {
    @Test func usesServerWorkingDirectoryWhenClaudeOmitsProjectPath() throws {
        let store = try makeStore()
        let tools = MarginTools(store: store, source: .claudeCode, defaultProjectPath: "/Users/x/Kariyer")
        let r = tools.call("save_note", ["content": .string("- SQL"), "summary": .string("s"), "note_title": .string("Skills")])
        #expect(r.text.contains("Kariyer › Skills"))
        #expect(try store.listTopics()[0].sources == ["/Users/x/Kariyer"])
    }

    @Test func explicitTopicStillRecordsFolder() throws {
        let store = try makeStore()
        let tools = MarginTools(store: store, source: .claudeCode, defaultProjectPath: "/Users/x/site")
        _ = tools.call("save_note", ["content": .string("x"), "summary": .string("s"), "topic": .string("Web sitesi")])
        #expect(try store.listTopics()[0].sources == ["/Users/x/site"])
    }

    @Test func ignoresUselessWorkingDirectories() {
        #expect(MarginTools.usableProjectPath("/") == nil)
        #expect(MarginTools.usableProjectPath(NSHomeDirectory()) == nil)
        #expect(MarginTools.usableProjectPath("/Users/x/Kariyer") == "/Users/x/Kariyer")
    }
}
