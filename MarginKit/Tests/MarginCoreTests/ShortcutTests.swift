import Foundation
import Testing
@testable import MarginCore

struct ShortcutTests {
    private let settings = MarginSettings(smartPrefix: "//m", instantPrefix: "//m!")

    @Test func classifyPrompt() {
        #expect(settings.classify("//m! süt al") == .instant("süt al"))
        #expect(settings.classify("  //m SQL'i ekle") == .smart("SQL'i ekle"))
        #expect(settings.classify("//mehmet'e sor") == .none)
        #expect(settings.classify("//m") == .none)
        #expect(settings.classify("normal mesaj //m") == .none)
    }

    @Test func settingsRoundTripAndDefaults() throws {
        let url = tempRoot().appendingPathComponent("settings.json")
        #expect(MarginSettings.load(from: url) == MarginSettings.default)
        try MarginSettings(smartPrefix: "::n", instantPrefix: "::n!").save(to: url)
        #expect(MarginSettings.load(from: url).smartPrefix == "::n")
    }

    @Test func emptyOrClashingPrefixesFallBack() {
        let s = MarginSettings(smartPrefix: "", instantPrefix: "//m").sanitized()
        #expect(s == MarginSettings.default)
    }

    @Test func quickCaptureAppendsTimestampedLines() throws {
        let store = try makeStore()
        let r1 = try store.quickCapture("süt al", projectPath: "/u/Kariyer", by: .claudeCode, noteTitle: "Hızlı notlar")
        _ = try store.quickCapture("Ali'yi ara", projectPath: "/u/Kariyer", by: .claudeCode, noteTitle: "Hızlı notlar")
        let body = try store.findNote(id: r1.meta.id).1.body
        let lines = body.split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[0].hasPrefix("- ") && lines[0].hasSuffix("süt al"))
        #expect(lines[1].hasSuffix("Ali'yi ara"))
        #expect(r1.topic.title == "Kariyer")
    }

    @Test func hookBlocksInstantAndSaves() throws {
        let store = try makeStore()
        let input = #"{"prompt":"//m! süt al","cwd":"/u/Kariyer","hook_event_name":"UserPromptSubmit"}"#
        let out = HookHandler(store: store, settings: settings, quickNoteTitle: "Hızlı notlar").handle(Data(input.utf8))
        let json = try JSONSerialization.jsonObject(with: out!) as! [String: Any]
        #expect(json["decision"] as? String == "block")
        #expect((json["reason"] as? String)?.contains("Kariyer › Hızlı notlar") == true)
        #expect(try store.search("süt al").count == 1)
    }

    @Test func hookAddsContextForSmart() throws {
        let store = try makeStore()
        let input = #"{"prompt":"//m SQL ekle","cwd":"/u/Kariyer","hook_event_name":"UserPromptSubmit"}"#
        let out = HookHandler(store: store, settings: settings, quickNoteTitle: "Q").handle(Data(input.utf8))
        let json = try JSONSerialization.jsonObject(with: out!) as! [String: Any]
        let specific = json["hookSpecificOutput"] as! [String: Any]
        #expect(specific["hookEventName"] as? String == "UserPromptSubmit")
        #expect((specific["additionalContext"] as? String)?.contains("Anthology") == true)
        #expect(try store.listTopics().isEmpty)
    }

    @Test func hookIgnoresOtherPromptsAndGarbage() throws {
        let store = try makeStore()
        let h = HookHandler(store: store, settings: settings, quickNoteTitle: "Q")
        #expect(h.handle(Data(#"{"prompt":"hello"}"#.utf8)) == nil)
        #expect(h.handle(Data("not json".utf8)) == nil)
    }

    @Test func hookConfigInstallPreservesOtherHooks() throws {
        let dir = tempRoot()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("settings.json")
        try #"{"model":"opus","hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"other"}]}],"Stop":[]}}"#.write(to: url, atomically: true, encoding: .utf8)
        try ClaudeHookConfig.install(at: url, command: "/bin/anthology-mcp hook")
        try ClaudeHookConfig.install(at: url, command: "/bin/anthology-mcp hook") // idempotent
        #expect(ClaudeHookConfig.isInstalled(at: url, command: "/bin/anthology-mcp hook"))
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        #expect(root["model"] as? String == "opus")
        let ups = (root["hooks"] as! [String: Any])["UserPromptSubmit"] as! [[String: Any]]
        #expect(ups.count == 2)
        try ClaudeHookConfig.remove(at: url)
        #expect(!ClaudeHookConfig.isInstalled(at: url, command: "/bin/anthology-mcp hook"))
        let after = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        #expect(((after["hooks"] as! [String: Any])["UserPromptSubmit"] as! [[String: Any]]).count == 1)
    }
}
