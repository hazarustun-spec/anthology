import Foundation
import Testing
@testable import MarginCore

struct ClaudeConfigTests {
    private func tempFile(_ contents: String?) throws -> URL {
        let dir = tempRoot()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("config.json")
        if let contents { try contents.write(to: url, atomically: true, encoding: .utf8) }
        return url
    }

    private func json(_ url: URL) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    }

    @Test func installPreservesOtherKeysAndBacksUp() throws {
        let url = try tempFile(#"{"preferences":{"x":1},"mcpServers":{"Blender":{"command":"/b"}}}"#)
        try MCPConfigFile.install(at: url, entry: ["command": "/m", "args": ["--source", "cowork"]])
        let d = try json(url)
        #expect((d["preferences"] as? [String: Any])?["x"] as? Int == 1)
        let servers = d["mcpServers"] as! [String: Any]
        #expect((servers["Blender"] as? [String: Any])?["command"] as? String == "/b")
        #expect((servers["anthology"] as? [String: Any])?["command"] as? String == "/m")
        let backups = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path).filter { $0.contains("anthology-backup") }
        #expect(backups.count == 1)
    }

    @Test func installCreatesMissingFile() throws {
        let url = try tempFile(nil)
        try MCPConfigFile.install(at: url, entry: ["command": "/m"])
        #expect(MCPConfigFile.status(at: url, binary: "/m") == .connected)
    }

    @Test func malformedFileIsNeverOverwritten() throws {
        let url = try tempFile("{ not json")
        #expect(throws: MCPConfigFile.ConfigError.self) {
            try MCPConfigFile.install(at: url, entry: ["command": "/m"])
        }
        #expect(try String(contentsOf: url, encoding: .utf8) == "{ not json")
        #expect(MCPConfigFile.status(at: url, binary: "/m") == .unreadable)
    }

    @Test func statusReportsStalePath() throws {
        let url = try tempFile(#"{"mcpServers":{"anthology":{"command":"/old"}}}"#)
        #expect(MCPConfigFile.status(at: url, binary: "/new") == .differentBinary)
        #expect(MCPConfigFile.status(at: try tempFile(#"{}"#), binary: "/new") == .notConnected)
    }

    @Test func removeKeepsEverythingElse() throws {
        let url = try tempFile(#"{"a":true,"mcpServers":{"anthology":{"command":"/m"},"x":{"command":"/x"}}}"#)
        try MCPConfigFile.remove(at: url)
        let d = try json(url)
        #expect(d["a"] as? Bool == true)
        #expect((d["mcpServers"] as! [String: Any]).keys.sorted() == ["x"])
    }
}
