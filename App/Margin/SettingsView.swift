import MarginCore
import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance: AppearanceChoice = .system
    @State private var connection = ClaudeConnection()

    var body: some View {
        Form {
            Section {
                ConnectionRow(
                    title: "Claude Code",
                    detail: "Code tab in the Claude app, and the terminal",
                    symbol: "chevron.left.forwardslash.chevron.right",
                    client: .claudeCode, connection: connection
                )
                ConnectionRow(
                    title: "Claude Desktop and Cowork",
                    detail: "Claude restarts once to load Margin",
                    symbol: "sparkles",
                    client: .claudeDesktop, connection: connection
                )
                if let error = connection.lastError {
                    Text(error).font(.callout).foregroundStyle(.red)
                }
            } header: {
                Text("Connect to Claude")
            } footer: {
                Text("Then just say \"save this to Margin\" in any conversation.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppearanceChoice.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .tint(Color(palette: Palette.accent))
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .onAppear { connection.refresh() }
    }
}

private struct ConnectionRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let symbol: String
    let client: ClaudeConnection.Client
    let connection: ClaudeConnection

    var body: some View {
        let status = connection.status[client] ?? .notConnected
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15)).foregroundStyle(Color(palette: Palette.accent))
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
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Color(palette: Palette.accent))
                    .contextMenu { Button("Disconnect") { connection.disconnect(client) } }
            } else if status == .unreadable {
                Text("Config file unreadable").font(.system(size: 12)).foregroundStyle(.orange)
            } else {
                Button(status == .differentBinary ? "Update" : "Connect") { connection.connect(client) }
                    .buttonStyle(.borderedProminent).tint(Color(palette: Palette.accent))
            }
        }
        .padding(.vertical, 4)
    }
}
