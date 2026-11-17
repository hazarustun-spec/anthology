import Foundation
import Testing
@testable import MarginCore

struct RenameAndAppearanceTests {
    @Test func renameKeepsIDAndOldTitleStillFindsNote() throws {
        let store = try makeStore()
        let t = try store.createTopic(title: "Kariyer", source: nil)
        let n = try store.createNote(topicID: t.id, title: "Skills", body: "- SQL", by: .claudeCode, summary: "c", project: nil)
        let renamed = try store.renameNote(id: n.meta.id, title: "Kazanmak istediğim skiller", by: .app)
        #expect(renamed.meta.id == n.meta.id)
        #expect(renamed.meta.title == "Kazanmak istediğim skiller")
        #expect(try store.findNote(topicID: t.id, title: "skills")?.0.meta.id == n.meta.id)
        #expect(try store.findNote(id: n.meta.id).1.aliases == ["Skills"])
        let tools = MarginTools(store: store, source: .claudeCode)
        #expect(tools.call("list_topics", [:]).text.contains("formerly \"Skills\""))
        // Saving with the old title appends to the same note instead of creating a duplicate.
        _ = tools.call("save_note", ["content": .string("- Go"), "summary": .string("s"), "topic": .string("Kariyer"), "note_title": .string("Skills")])
        #expect(try store.listNotes(topicID: t.id).count == 1)
    }

    @Test func aliasesRoundTripInFrontMatter() throws {
        var file = NoteFile(meta: NoteMeta(id: newID(), title: "B", created: MarginDate.now(), updated: MarginDate.now(), revision: 1), body: "x")
        file.aliases = ["A", "Eski: \"ad\""]
        #expect(try NoteFile.parse(file.serialize()) == file)
    }

    @Test func topicAppearancePersists() throws {
        let store = try makeStore()
        let t = try store.createTopic(title: "Kariyer", source: nil)
        _ = try store.setTopicAppearance(id: t.id, icon: "briefcase", color: "sage")
        let again = try store.topic(id: t.id)
        #expect(again.icon == "briefcase")
        #expect(again.color == "sage")
    }

    @Test func quickCaptureIntoTopic() throws {
        let store = try makeStore()
        let t = try store.createTopic(title: "Inbox", source: nil)
        let ref = try store.quickCapture("idea", topicID: t.id, by: .app, noteTitle: "Quick notes")
        #expect(ref.topic.id == t.id)
        #expect(try store.findNote(id: ref.meta.id).1.body.hasSuffix("idea"))
    }
}

struct GuardTests {
    @Test func deleteIsOffByDefaultAndHidden() throws {
        let store = try makeStore()
        let tools = MarginTools(store: store, source: .claudeCode, settings: .default)
        #expect(!tools.specs.map(\.name).contains("delete_note"))
        _ = tools.call("save_note", ["content": .string("x"), "summary": .string("s"), "topic": .string("T")])
        let id = try store.listNotes(topicID: store.listTopics()[0].id)[0].meta.id
        let r = tools.call("delete_note", ["note_id": .string(id)])
        #expect(r.isError)
        #expect(try store.listNotes(topicID: store.listTopics()[0].id).count == 1)

        var allow = MarginSettings.default
        allow.allowDelete = true
        #expect(MarginTools(store: store, source: .claudeCode, settings: allow).specs.map(\.name).contains("delete_note"))
    }

    @Test func largeRemovalIsFlaggedAndRecoverable() throws {
        let store = try makeStore()
        let tools = MarginTools(store: store, source: .claudeCode)
        _ = tools.call("save_note", ["content": .string(String(repeating: "important line\n", count: 20)), "summary": .string("s"), "topic": .string("T"), "note_title": .string("N")])
        let id = try store.listNotes(topicID: store.listTopics()[0].id)[0].meta.id
        let r = tools.call("update_note", ["note_id": .string(id), "base_revision": .int(1), "content": .string("short"), "summary": .string("cleanup")])
        #expect(!r.isError)
        #expect(r.text.contains("previous version"))
        #expect(try store.history(noteID: id).last?.warning == "large-removal")
    }

    @Test func writesAreRateLimited() throws {
        let store = try makeStore()
        let tools = MarginTools(store: store, source: .claudeCode, writeLimit: 3)
        for i in 0..<3 {
            #expect(!tools.call("save_note", ["content": .string("\(i)"), "summary": .string("s"), "topic": .string("T")]).isError)
        }
        let blocked = tools.call("save_note", ["content": .string("x"), "summary": .string("s"), "topic": .string("T")])
        #expect(blocked.isError)
        #expect(blocked.text.contains("Too many"))
        #expect(!tools.call("list_topics", [:]).isError)
    }

    @Test func toolHints() {
        let specs = Dictionary(uniqueKeysWithValues: MarginTools.toolSpecs.map { ($0.name, $0) })
        #expect(specs["get_note"]?.readOnly == true)
        #expect(specs["update_note"]?.destructive == true)
        #expect(specs["save_note"]?.destructive == false)
    }

    @Test func settingsDecodeOldFilesWithDefaults() throws {
        let url = tempRoot().appendingPathComponent("s.json")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try #"{"smartPrefix":"::n","instantPrefix":"::n!"}"#.write(to: url, atomically: true, encoding: .utf8)
        let s = MarginSettings.load(from: url)
        #expect(s.smartPrefix == "::n")
        #expect(s.allowDelete == false)
    }
}

struct ClientConfigTests {
    private func file(_ name: String, _ contents: String?) throws -> URL {
        let dir = tempRoot()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        if let contents { try contents.write(to: url, atomically: true, encoding: .utf8) }
        return url
    }

    @Test func vscodeUsesServersKey() throws {
        let url = try file("mcp.json", #"{"servers":{"other":{"command":"x"}}}"#)
        try MCPConfigFile.install(at: url, entry: ["type": "stdio", "command": "/m"], key: "servers")
        #expect(MCPConfigFile.status(at: url, binary: "/m", key: "servers") == .connected)
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        #expect((root["servers"] as! [String: Any]).keys.sorted() == ["anthology", "other"])
    }

    @Test func codexHeaderWithCommentIsReplacedNotDuplicated() throws {
        let url = tempRoot().appendingPathComponent("config.toml")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "model = \"x\"\n\n[ mcp_servers.anthology ] # mine\ncommand = \"/old\"\n".write(to: url, atomically: true, encoding: .utf8)
        try CodexConfig.install(at: url, command: "/new", args: [])
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.components(separatedBy: "mcp_servers.anthology").count == 2)
        #expect(text.contains("command = \"/new\""))
        #expect(!text.contains("/old"))
    }

    @Test func codexUnreadableFileIsNotOverwritten() throws {
        let url = tempRoot().appendingPathComponent("config.toml")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0xFF, 0xFE, 0x00, 0xC3]).write(to: url)
        #expect(throws: (any Error).self) { try CodexConfig.install(at: url, command: "/new", args: []) }
        #expect(try Data(contentsOf: url) == Data([0xFF, 0xFE, 0x00, 0xC3]))
    }

    @Test func codexTomlInstallReplaceRemove() throws {
        let original = "model = \"o3\"\n\n[mcp_servers.other]\ncommand = \"x\"\n\n[profiles.fast]\nmodel = \"mini\"\n"
        let url = try file("config.toml", original)
        try CodexConfig.install(at: url, command: "/Users/a b/anthology-mcp", args: ["--source", "codex"])
        try CodexConfig.install(at: url, command: "/Users/a b/anthology-mcp", args: ["--source", "codex"])
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.components(separatedBy: "[mcp_servers.anthology]").count == 2)
        #expect(text.contains("command = \"/Users/a b/anthology-mcp\""))
        #expect(text.contains("args = [\"--source\", \"codex\"]"))
        #expect(text.contains("[profiles.fast]\nmodel = \"mini\""))
        #expect(CodexConfig.status(at: url, command: "/Users/a b/anthology-mcp") == .connected)
        try CodexConfig.remove(at: url)
        #expect(try String(contentsOf: url, encoding: .utf8) == original)
    }

    @Test func codexMissingFileCreated() throws {
        let url = try file("config.toml", nil)
        try CodexConfig.install(at: url, command: "/m", args: [])
        #expect(CodexConfig.status(at: url, command: "/m") == .connected)
    }

    @Test func newSourcesHaveRawValues() {
        #expect(ChangeSource(rawValue: "gemini") == .gemini)
        #expect(ChangeSource(rawValue: "codex") == .codex)
        #expect(ChangeSource(rawValue: "cursor") == .cursor)
        #expect(ChangeSource(rawValue: "vscode") == .vscode)
    }
}
