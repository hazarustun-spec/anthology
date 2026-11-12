import MarginCore
import SwiftUI

struct LibraryView: View {
    @Environment(LibraryModel.self) private var library
    @State private var selectedTopic: String?
    @State private var selectedNote: String?

    var body: some View {
        NavigationSplitView {
            TopicList(selection: $selectedTopic)
        } content: {
            if let selectedTopic {
                NoteList(topicID: selectedTopic, selection: $selectedNote)
            } else {
                EmptyState(symbol: "folder", text: "Pick a topic")
            }
        } detail: {
            if let selectedNote {
                NoteReader(noteID: selectedNote)
            } else {
                EmptyState(symbol: "text.alignleft", text: "Pick a note")
            }
        }
        .onChange(of: selectedTopic) { selectedNote = library.notes(for: selectedTopic ?? "").first?.meta.id }
        .onAppear { selectedTopic = selectedTopic ?? library.topics.first?.id }
    }
}

struct EmptyState: View {
    let symbol: String
    let text: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 28, weight: .light))
            Text(text).font(.callout)
        }
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
