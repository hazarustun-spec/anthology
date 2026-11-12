import MarginCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage("settingsTab") private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            GeneralSettings().tabItem { Label("General", systemImage: "gearshape") }.tag(0)
            ConnectionSettings().tabItem { Label("Connections", systemImage: "point.3.connected.trianglepath.dotted") }.tag(1)
            ShortcutSettings().tabItem { Label("Shortcuts", systemImage: "keyboard") }.tag(2)
        }
        .frame(width: 560)
        .tint(Color(palette: Palette.accent))
    }
}

// MARK: General

private struct GeneralSettings: View {
    @AppStorage("appearance") private var appearance: AppearanceChoice = .system
    @AppStorage(AppLock.timeoutKey) private var lockAfter = 5
    @AppStorage(Notifier.enabledKey) private var notify = true
    @State private var lockOn = UserDefaults.standard.bool(forKey: AppLock.enabledKey)
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @Environment(AppLock.self) private var lock

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppearanceChoice.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                Toggle("Lock Margin with \(AppLock.biometryName)", isOn: Binding(get: { lockOn }, set: { new in
                    lock.setEnabled(new) { ok in lockOn = ok ? new : lockOn }
                }))
                if lockOn {
                    Picker("Lock after", selection: $lockAfter) {
                        Text("Immediately").tag(0)
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("1 hour").tag(60)
                    }
                }
            } header: { Text("Privacy") } footer: {
                Text("Margin also locks when your Mac sleeps.").font(.callout).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Notify when an AI tool changes a note", isOn: $notify)
                Toggle("Open Margin at login", isOn: Binding(get: { openAtLogin }, set: { new in
                    do { if new { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch {}
                    openAtLogin = SMAppService.mainApp.status == .enabled
                }))
            } header: { Text("Background") } footer: {
                Text("Notifications are silent. Margin keeps running in the menu bar after you close its window, so it can tell you about changes.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: Connections

private struct ConnectionSettings: View {
    @State private var connection = ClaudeConnection()
    @State private var settings = MarginSettings.load()

    var body: some View {
        Form {
            Section {
                ConnectionRow(title: "Claude Code", detail: "Code tab in the Claude app, and the terminal", symbol: "chevron.left.forwardslash.chevron.right", client: .claudeCode, connection: connection)
                ConnectionRow(title: "Claude Desktop and Cowork", detail: "Claude restarts once to load Margin", symbol: "sparkles", client: .claudeDesktop, connection: connection)
            } header: { Text("Claude") }
            Section {
                ConnectionRow(title: "Gemini CLI", detail: "~/.gemini/settings.json", symbol: "diamond", client: .geminiCLI, connection: connection)
                ConnectionRow(title: "Cursor", detail: "~/.cursor/mcp.json", symbol: "cursorarrow.rays", client: .cursor, connection: connection)
                ConnectionRow(title: "VS Code", detail: "Copilot agent mode", symbol: "curlybraces", client: .vscode, connection: connection)
                ConnectionRow(title: "Codex", detail: "~/.codex/config.toml", symbol: "terminal", client: .codex, connection: connection)
                if let error = connection.lastError {
                    Text(error).font(.callout).foregroundStyle(.red)
                }
            } header: { Text("Other AI tools") } footer: {
                Text("Restart a tool after connecting it.").font(.callout).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Allow AI tools to move notes between topics", isOn: $settings.allowMove)
                Toggle("Allow AI tools to delete notes", isOn: $settings.allowDelete)
            } header: { Text("What AI tools may do") } footer: {
                Text("Every AI change is kept in the note's history and can be undone. Deleting is off by default, so a tool tricked by a web page can't remove your notes.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { connection.refresh() }
        .onChange(of: settings) { _, new in try? new.save() }
    }
}

struct ConnectionRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let symbol: String
    let client: ClaudeConnection.Client
    let connection: ClaudeConnection

    var body: some View {
        let status = connection.status[client] ?? .notConnected
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14)).foregroundStyle(Color(palette: Palette.accent))
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(palette: Palette.accentWash)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if connection.working == client {
                ProgressView().controlSize(.small)
            } else if status == .connected {
                Menu {
                    Button("Disconnect") { connection.disconnect(client) }
                } label: {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                }
                .menuStyle(.borderlessButton).fixedSize()
                .font(.system(size: 12, weight: .medium)).foregroundStyle(Color(palette: Palette.accent))
            } else if status == .unreadable {
                Text("Config file unreadable").font(.system(size: 12)).foregroundStyle(.orange)
            } else {
                Button(status == .differentBinary ? "Update" : "Connect") { connection.connect(client) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: Shortcuts

private struct ShortcutSettings: View {
    @State private var settings = MarginSettings.load()

    var body: some View {
        Form {
            Section {
                prefixRow("Smart save", "Claude files it into the right note", $settings.smartPrefix)
                prefixRow("Instant capture", "Saved word for word to Quick notes, never sent to Claude", $settings.instantPrefix)
            } header: { Text("Chat shortcuts") } footer: {
                Text("Example: \(settings.smartPrefix) add SQL to my skills · \(settings.instantPrefix) call Ali tomorrow. New conversations pick up changes.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Quick note window") { HotkeyRecorder() }
            } header: { Text("Keyboard") } footer: {
                Text("Works from any app. Click, then press a new combination; Delete turns it off.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings) { _, new in
            if new.sanitized() == new { try? new.save() }
        }
    }

    private func prefixRow(_ title: LocalizedStringKey, _ detail: LocalizedStringKey, _ value: Binding<String>) -> some View {
        LabeledContent {
            TextField("", text: value)
                .textFieldStyle(.roundedBorder).frame(width: 90)
                .font(.system(.body, design: .monospaced))
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }
}
