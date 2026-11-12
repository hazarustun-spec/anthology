import MarginCore
import SwiftUI

struct NoteList: View {
    @Environment(LibraryModel.self) private var library
    let topicID: String
    @Binding var selection: String?

    var body: some View {
        List(selection: $selection) {
            ForEach(library.notes(for: topicID), id: \.meta.id) { note in
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.meta.title).font(.headline)
                    Text(note.meta.updated, format: .relative(presentation: .named))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .listRowBackground(
                    library.isRecentlyChanged(note.meta.id)
                        ? RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.15)) : nil
                )
                .tag(note.meta.id)
            }
        }
        .animation(.easeOut(duration: 0.6), value: library.recentlyChanged)
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
    }
}
