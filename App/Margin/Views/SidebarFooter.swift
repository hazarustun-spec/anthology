import AppKit
import SwiftUI

/// Sidebar button into Settings › Connections (the menu-bar item alone was too hidden).
/// A dot appears when no AI tool is connected yet, or a connected one needs "Update".
struct SidebarFooter: View {
    @Environment(\.openSettings) private var openSettings
    @AppStorage("settingsTab") private var settingsTab = 0
    @State private var connection = ClaudeConnection()

    private var needsAttention: Bool {
        let states = connection.status.values
        return !states.contains(.connected) || states.contains(.differentBinary)
    }

    var body: some View {
        Button {
            settingsTab = 1
            openSettings()
        } label: {
            HStack(spacing: 6) {
                Label("Connections", systemImage: "gearshape")
                if needsAttention {
                    Circle()
                        .fill(Color(palette: Palette.accent))
                        .frame(width: 6, height: 6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help("Connect your AI tools (⌘,)")
        .animation(.easeOut(duration: 0.2), value: needsAttention)
        .onAppear { connection.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            connection.refresh()
        }
    }
}
