import MarginCore
import SwiftUI

struct NoteList: View {
    @Environment(LibraryModel.self) private var library

    var body: some View {
        let notes = library.notes(for: library.selectedTopicID)
        ScrollView {
            GlassEffectContainer(spacing: 2) {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(notes, id: \.meta.id) { note in row(note) }
            }
            .padding(.horizontal, 12).padding(.vertical, 12)
            }
        }
        .scrollEdgeEffectStyle(.hard, for: .top)
        .overlay { if notes.isEmpty { EmptyState(symbol: "tray", title: "No notes yet", message: "Notes Claude saves from this folder appear here.") } }
        .animation(.easeOut(duration: 0.5), value: library.freshNotes)
    }

    @ViewBuilder
    private func row(_ note: NoteRef) -> some View {
        let selected = library.selectedNoteID == note.meta.id
        let fresh = library.isFresh(note.meta.id)
        let last = library.lastChange(for: note.meta.id)
        VStack(alignment: .leading, spacing: 4) {
            Text(note.meta.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(palette: Palette.text)).lineLimit(1)
            Text(preview(library.body(for: note.meta.id)))
                .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
            HStack(spacing: 4) {
                Text(note.meta.updated, format: .relative(presentation: .named))
                if let last, last.by != .app {
                    Text("·"); Text(last.by.label)
                }
            }
            .font(.system(size: 11)).foregroundStyle(fresh ? AnyShapeStyle(Color(palette: Palette.accentText)) : AnyShapeStyle(.secondary))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 16, fill: selected ? 0.45 : 0.08, clear: true, interactive: true,
                    tint: fresh ? Color(palette: Palette.accent).opacity(0.35) : nil)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color(palette: Palette.accent).opacity(selected ? 0.55 : 0), lineWidth: 1.2))
        .contentShape(.rect(cornerRadius: 16))
        .contentShape(Rectangle())
        .onTapGesture { library.selectedNoteID = note.meta.id }
        .draggable(note.meta.id) {
            Label(note.meta.title, systemImage: "doc.text")
                .padding(8).background(RoundedRectangle(cornerRadius: 8).fill(Color(palette: Palette.card)))
        }
        .contextMenu { NoteMenu(note: note) }
    }

    private func preview(_ body: String) -> String {
        body.split(separator: "\n").map { NoteText.plain(String($0)) }.filter { !$0.isEmpty }.prefix(3).joined(separator: " · ")
    }
}


struct NoteMenu: View {
    @Environment(LibraryModel.self) private var library
    let note: NoteRef

    var body: some View {
        Button("Copy as Markdown") { NoteExport.copyMarkdown(title: note.meta.title, body: library.body(for: note.meta.id)) }
        Button("Export as PDF…") { NoteExport.exportPDF(title: note.meta.title, body: library.body(for: note.meta.id)) }
        Button("Show in Finder") { NoteExport.reveal(note.fileURL) }
        Menu("Move to") {
            ForEach(library.topics.filter { $0.id != note.topic.id }) { t in
                Button(t.title) { library.moveNote(note.meta.id, to: t.id) }
            }
        }
        Divider()
        Button("Move to Trash", role: .destructive) { library.deleteNote(note.meta.id) }
    }
}

