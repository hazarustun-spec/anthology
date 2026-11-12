import MarginCore
import SwiftUI

struct NoteReader: View {
    @Environment(LibraryModel.self) private var library
    let noteID: String

    var body: some View {
        let note = library.notesByTopic.values.joined().first { $0.meta.id == noteID }
        let history = library.history(for: noteID)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let note {
                    Text(note.meta.title)
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                    if let last = history.last {
                        SourceBadge(entry: last)
                    }
                }
                Text(rendered(library.body(for: noteID)))
                    .font(.system(size: 16, design: .serif))
                    .lineSpacing(6)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 48)
            .padding(.vertical, 36)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .id(note?.meta.revision)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: note?.meta.revision)
    }

    private func rendered(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(markdown)
    }
}

struct SourceBadge: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(label)
            Text("·")
            Text(entry.summary).lineLimit(1)
            Text("·")
            Text(entry.at, format: .relative(presentation: .named))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.quaternary.opacity(0.5), in: Capsule())
    }

    private var label: LocalizedStringKey {
        switch entry.by {
        case .claudeCode: "via Claude Code"
        case .cowork: "via Cowork"
        case .app: "by you"
        }
    }

    private var icon: String {
        entry.by == .app ? "person" : "sparkles"
    }
}
