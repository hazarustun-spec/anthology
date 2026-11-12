import MarginCore
import SwiftUI

struct NoteList: View {
    @Environment(LibraryModel.self) private var library

    var body: some View {
        let notes = library.notes(for: library.selectedTopicID)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                if let topic = library.topics.first(where: { $0.id == library.selectedTopicID }) {
                    HStack {
                        Text(topic.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Color(palette: Palette.text))
                        Spacer()
                        Button { library.createNote(in: topic.id) } label: { Image(systemName: "square.and.pencil") }
                            .buttonStyle(.plain).foregroundStyle(Color(palette: Palette.secondary)).help("New note")
                    }
                    .padding(.horizontal, 10).padding(.bottom, 8)
                }
                ForEach(notes, id: \.meta.id) { note in row(note) }
            }
            .padding(.horizontal, 10).padding(.top, 14)
        }
        .scrollContentBackground(.hidden)
        .background(Color(palette: Palette.list))
        .overlay { if notes.isEmpty { EmptyState(symbol: "tray", title: "No notes yet", message: "Notes Claude saves from this folder appear here.") } }
        .animation(.easeOut(duration: 0.5), value: library.freshNotes)
    }

    @ViewBuilder
    private func row(_ note: NoteRef) -> some View {
        let selected = library.selectedNoteID == note.meta.id
        let fresh = library.isFresh(note.meta.id)
        let last = library.lastChange(for: note.meta.id)
        VStack(alignment: .leading, spacing: 4) {
            Text(note.meta.title).font(.system(size: 13, weight: .medium)).foregroundStyle(Color(palette: Palette.text)).lineLimit(1)
            Text(preview(library.body(for: note.meta.id)))
                .font(.system(size: 12)).foregroundStyle(Color(palette: Palette.secondary)).lineLimit(2)
            HStack(spacing: 4) {
                Text(note.meta.updated, format: .relative(presentation: .named))
                if let last, last.by != .app {
                    Text("·"); Text(last.by.label)
                }
            }
            .font(.system(size: 11)).foregroundStyle(Color(palette: fresh ? Palette.accent : Palette.tertiary))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(palette: fresh ? Palette.accentWash : Palette.card))
                .overlay(
                    RoundedRectangle(cornerRadius: 10).strokeBorder(
                        Color(palette: selected || fresh ? Palette.accentBorder : Palette.hairline),
                        lineWidth: selected || fresh ? 1 : 0.5
                    )
                )
        )
        .padding(.bottom, 4)
        .contentShape(Rectangle())
        .onTapGesture { library.selectedNoteID = note.meta.id }
        .contextMenu {
            Button("Move to Trash", role: .destructive) { library.deleteNote(note.meta.id) }
        }
    }

    private func preview(_ body: String) -> String {
        body.split(separator: "\n")
            .map { line -> String in
                var l = String(line)
                for marker in ["- [ ] ", "- [x] ", "- [X] "] where l.hasPrefix(marker) { l.removeFirst(marker.count) }
                l = l.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
                return l.trimmingCharacters(in: CharacterSet(charactersIn: "#-*+_").union(.whitespaces))
            }
            .filter { !$0.isEmpty }.prefix(3).joined(separator: " · ")
    }
}

extension ChangeSource {
    var label: LocalizedStringKey {
        switch self {
        case .claudeCode: "Claude Code"
        case .cowork: "Cowork"
        case .app: "You"
        }
    }

    var symbol: String { self == .app ? "person" : "sparkles" }
}
