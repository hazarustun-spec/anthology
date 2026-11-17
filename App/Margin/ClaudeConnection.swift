import AppKit
import Foundation
import MarginCore
import Observation

/// Installs the bundled anthology-mcp helper and registers it with Claude Code and Claude Desktop.
@MainActor @Observable
final class ClaudeConnection {
    enum Client: String, CaseIterable, Identifiable {
        case claudeCode, claudeDesktop, geminiCLI, cursor, vscode, codex
        var id: String { rawValue }

        var home: URL { FileManager.default.homeDirectoryForCurrentUser }

        /// JSON config file and the top-level key holding MCP servers (Codex uses TOML instead).
        var jsonConfig: (url: URL, key: String)? {
            switch self {
            case .claudeCode: (ClaudePaths.claudeCodeConfig, "mcpServers")
            case .claudeDesktop: (ClaudePaths.desktopConfig, "mcpServers")
            case .geminiCLI: (home.appendingPathComponent(".gemini/settings.json"), "mcpServers")
            case .cursor: (home.appendingPathComponent(".cursor/mcp.json"), "mcpServers")
            case .vscode: (home.appendingPathComponent("Library/Application Support/Code/User/mcp.json"), "servers")
            case .codex: nil
            }
        }

        var source: String {
            switch self {
            case .claudeCode: "claude-code"
            case .claudeDesktop: "cowork"
            case .geminiCLI: "gemini"
            case .cursor: "cursor"
            case .vscode: "vscode"
            case .codex: "codex"
            }
        }

        func entry(helper: String) -> [String: Any] {
            switch self {
            case .claudeCode: ["type": "stdio", "command": helper, "args": [], "env": [:]]
            case .vscode: ["type": "stdio", "command": helper, "args": ["--source", source]]
            default: ["command": helper, "args": ["--source", source]]
            }
        }
    }

    private(set) var status: [Client: MCPConfigFile.Status] = [:]
    private(set) var working: Client?
    private(set) var lastError: String?

    var helperPath: String { ClaudePaths.installedHelper.path }

    init() { refresh() }

    var hookCommand: String { "\"\(helperPath)\" hook" }

    func refresh() {
        var code = MCPConfigFile.status(at: ClaudePaths.claudeCodeConfig, binary: helperPath)
        // The shortcut hook is part of the Claude Code connection; offer "Update" when it is missing.
        if code == .connected, !ClaudeHookConfig.isInstalled(command: hookCommand) { code = .differentBinary }
        status[.claudeCode] = code
        for client in Client.allCases where client != .claudeCode {
            if let cfg = client.jsonConfig {
                status[client] = MCPConfigFile.status(at: cfg.url, binary: helperPath, key: cfg.key)
            } else {
                status[client] = CodexConfig.status(command: helperPath)
            }
        }
        // The installed helper must be byte-identical to the one in this app; otherwise offer "Update".
        if !installedHelperMatchesBundle {
            for client in Client.allCases where status[client] == .connected { status[client] = .differentBinary }
        }
    }

    func connect(_ client: Client) {
        working = client
        lastError = nil
        Task {
            do {
                try installHelper()
                switch client {
                case .claudeCode:
                    try await connectClaudeCode()
                    try ClaudeHookConfig.install(command: hookCommand)
                case .claudeDesktop: try await connectClaudeDesktop()
                case .codex: try CodexConfig.install(command: helperPath, args: ["--source", client.source])
                default:
                    if let cfg = client.jsonConfig {
                        try MCPConfigFile.install(at: cfg.url, entry: client.entry(helper: helperPath), key: cfg.key)
                    }
                }
            } catch {
                lastError = error.localizedDescription
            }
            working = nil
            refresh()
        }
    }

    func disconnect(_ client: Client) {
        do {
            switch client {
            case .claudeCode:
                try MCPConfigFile.remove(at: ClaudePaths.claudeCodeConfig)
                try ClaudeHookConfig.remove()
            case .codex: try CodexConfig.remove()
            default:
                if let cfg = client.jsonConfig { try MCPConfigFile.remove(at: cfg.url, key: cfg.key) }
            }
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    static let desktopBundleID = "com.anthropic.claudefordesktop"

    var isClaudeDesktopRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.desktopBundleID).isEmpty
    }

    /// Claude Desktop keeps its config in memory and writes it back, so edits made while it runs are lost.
    /// Quit it, write the config, then reopen it.
    private func connectClaudeDesktop() async throws {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: Self.desktopBundleID)
        let appURL = running.first?.bundleURL
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.desktopBundleID)
        for app in running { app.terminate() }
        for _ in 0..<100 where running.contains(where: { !$0.isTerminated }) {
            try await Task.sleep(for: .milliseconds(100))
        }
        guard !running.contains(where: { !$0.isTerminated }) else {
            throw NSError(domain: "Anthology", code: 2, userInfo: [NSLocalizedDescriptionKey: String(localized: "Quit Claude, then press Connect again.")])
        }
        try MCPConfigFile.install(at: ClaudePaths.desktopConfig, entry: Client.claudeDesktop.entry(helper: helperPath))
        if !running.isEmpty, let appURL {
            _ = try? await NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private var bundledHelper: URL { Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/anthology-mcp") }

    private var installedHelperMatchesBundle: Bool {
        guard let a = try? Data(contentsOf: bundledHelper, options: .mappedIfSafe),
              let b = try? Data(contentsOf: ClaudePaths.installedHelper, options: .mappedIfSafe) else { return false }
        return a == b
    }

    /// Copies the helper out of the app bundle to a stable path that survives moving the app.
    private func installHelper() throws {
        guard let bundled = Bundle.main.url(forAuxiliaryExecutable: "anthology-mcp")
                ?? Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/anthology-mcp") as URL?,
              FileManager.default.fileExists(atPath: bundled.path) else {
            throw NSError(domain: "Anthology", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "The Claude helper is missing from the app. Reinstall Anthology.")])
        }
        let dest = ClaudePaths.installedHelper
        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Replace, never overwrite in place: macOS kills binaries whose code-signature cache is stale.
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: bundled, to: dest)
    }

    /// Prefers the `claude` CLI (it owns ~/.claude.json); falls back to editing the file.
    private func connectClaudeCode() async throws {
        if let cli = ClaudePaths.claudeCLI() {
            _ = try? await run(cli, ["mcp", "remove", "anthology", "--scope", "user"])
            let ok = try await run(cli, ["mcp", "add", "--scope", "user", "anthology", "--", helperPath])
            if ok { return }
        }
        try MCPConfigFile.install(at: ClaudePaths.claudeCodeConfig, entry: ["type": "stdio", "command": helperPath, "args": [], "env": [:]])
    }

    private func run(_ exe: URL, _ args: [String]) async throws -> Bool {
        try await withCheckedThrowingContinuation { cont in
            let p = Process()
            p.executableURL = exe
            p.arguments = args
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            p.terminationHandler = { cont.resume(returning: $0.terminationStatus == 0) }
            do { try p.run() } catch { cont.resume(throwing: error) }
        }
    }
}
