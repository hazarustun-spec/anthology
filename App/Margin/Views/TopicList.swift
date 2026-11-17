import MarginCore
import SwiftUI

struct TopicList: View {
    @Environment(LibraryModel.self) private var library
    @State private var renaming: String?
    @State private var draftTitle = ""
    @State private var addingTopic = false
    @State private var styling: String?
    @State private var dropTarget: String?

    var body: some View {
        @Bindable var library = library
        List(selection: Binding(get: { library.selectedTopicID }, set: { library.selectTopic($0) })) {
            Section("Topics") {
                ForEach(library.topics) { topic in
                    row(topic).tag(topic.id)
                }
                if addingTopic {
                    TextField("New topic", text: $draftTitle)
                        .onSubmit { library.createTopic(title: draftTitle); addingTopic = false }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button { draftTitle = ""; addingTopic = true } label: { Label("New topic", systemImage: "plus") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
        }
        .animation(.spring(duration: 0.35), value: library.freshNotes)
    }

    @ViewBuilder
    private func row(_ topic: Topic) -> some View {
        let selected = library.selectedTopicID == topic.id
        HStack(spacing: 8) {
            // Selected rows let the system pick the icon color so it stays legible on the highlight.
            if selected {
                Image(systemName: topic.icon ?? "folder")
            } else {
                Image(systemName: topic.icon ?? "folder").foregroundStyle(TopicStyle.color(topic.color))
            }
            if renaming == topic.id {
                TextField("", text: $draftTitle)
                    .onSubmit { library.renameTopic(topic.id, to: draftTitle); renaming = nil }
            } else {
                Text(topic.title).lineLimit(1)
            }
            Spacer(minLength: 4)
            if library.topicHasFresh(topic.id) {
                Circle().fill(Color(palette: Palette.accent)).frame(width: 6, height: 6)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .badge(library.notes(for: topic.id).count)
        .listRowBackground(dropTarget == topic.id ? RoundedRectangle(cornerRadius: 8).fill(Color(palette: Palette.accentWash)) : nil)
        .dropDestination(for: String.self) { ids, _ in
            for id in ids { library.moveNote(id, to: topic.id) }
            return !ids.isEmpty
        } isTargeted: { dropTarget = $0 ? topic.id : (dropTarget == topic.id ? nil : dropTarget) }
        .popover(isPresented: Binding(get: { styling == topic.id }, set: { if !$0 { styling = nil } })) {
            TopicAppearancePicker(topic: topic) { icon, color in library.setAppearance(topicID: topic.id, icon: icon, color: color) }
        }
        .contextMenu {
            Button("Rename") { draftTitle = topic.title; renaming = topic.id }
            Button("Icon and color…") { styling = topic.id }
            Button("New note") { library.createNote(in: topic.id) }
            Divider()
            Button("Move to Trash", role: .destructive) { library.trashTopic(topic.id) }
        }
    }
}
