import MarginCore
import SwiftUI

struct MenuBarView: View {
    @Environment(LibraryModel.self) private var library
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Margin").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("Recent changes").font(.system(size: 11)).foregroundStyle(Color(palette: Palette.tertiary))
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            Divider().overlay(Color(palette: Palette.hairline))
            if library.activity.isEmpty {
                Text("Ask Claude to save something to Margin.")
                    .font(.system(size: 12)).foregroundStyle(Color(palette: Palette.secondary)).padding(14)
            }
            ForEach(library.activity.prefix(8)) { item in
                Button {
                    library.open(noteID: item.noteID)
                    openWindow(id: "library")
                    NSApp.activate()
                } label: {
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: item.entry.by.symbol).foregroundStyle(Color(palette: item.entry.by == .app ? Palette.secondary : Palette.accent)).frame(width: 14)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(item.topicTitle) › \(item.noteTitle)").font(.system(size: 12, weight: .medium)).lineLimit(1)
                            Text(item.entry.summary).font(.system(size: 11)).foregroundStyle(Color(palette: Palette.secondary)).lineLimit(1)
                        }
                        Spacer(minLength: 6)
                        Text(item.entry.at, format: .relative(presentation: .numeric, unitsStyle: .narrow))
                            .font(.system(size: 10)).foregroundStyle(Color(palette: Palette.tertiary))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Divider().overlay(Color(palette: Palette.hairline))
            HStack {
                Button("Open Margin") { openWindow(id: "library"); NSApp.activate() }
                    .buttonStyle(.glassProminent).tint(Color(palette: Palette.accent))
                Spacer()
                SettingsLink { Text("Settings…") }.buttonStyle(.glass)
            }
            .controlSize(.small).font(.system(size: 12))
            .padding(12)
        }
        .frame(width: 340)
    }
}
