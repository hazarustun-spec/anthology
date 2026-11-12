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
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Text("Topics")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(Color(palette: Palette.tertiary))
                    .padding(.horizontal, 10).padding(.bottom, 6)
                ForEach(library.topics) { topic in
                    row(topic)
                }
                if addingTopic {
                    TextField("New topic", text: $draftTitle)
                        .textFieldStyle(.plain).padding(8)
                        .onSubmit { library.createTopic(title: draftTitle); addingTopic = false }
                }
            }
            .padding(.horizontal, 10).padding(.top, 8)
        }
        .scrollContentBackground(.hidden)
        .background(Color(palette: Palette.sidebar))
        .overlay(alignment: .bottomLeading) {
            Button { draftTitle = ""; addingTopic = true } label: {
                Label("New topic", systemImage: "plus").font(.system(size: 12))
            }
            .buttonStyle(.plain).foregroundStyle(Color(palette: Palette.secondary)).padding(14)
        }
        .animation(.spring(duration: 0.35), value: library.freshNotes)
    }

    @ViewBuilder
    private func row(_ topic: Topic) -> some View {
        let selected = library.selectedTopicID == topic.id
        HStack(spacing: 8) {
            Image(systemName: topic.icon ?? "folder")
                .symbolVariant(selected ? .fill : .none)
                .font(.system(size: 12)).foregroundStyle(TopicStyle.color(topic.color))
                .frame(width: 16)
            if renaming == topic.id {
                TextField("", text: $draftTitle).textFieldStyle(.plain)
                    .onSubmit { library.renameTopic(topic.id, to: draftTitle); renaming = nil }
            } else {
                Text(topic.title).lineLimit(1).foregroundStyle(Color(palette: Palette.text))
            }
            Spacer(minLength: 4)
            if library.topicHasFresh(topic.id) {
                Circle().fill(Color(palette: Palette.accent)).frame(width: 6, height: 6)
                    .transition(.scale.combined(with: .opacity))
            }
            Text("\(library.notes(for: topic.id).count)")
                .font(.system(size: 11)).monospacedDigit().foregroundStyle(Color(palette: Palette.tertiary))
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(palette: dropTarget == topic.id ? Palette.accentWash : selected ? Palette.card : .clear))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(palette: dropTarget == topic.id ? Palette.accentBorder : selected ? Palette.hairline : .clear), lineWidth: dropTarget == topic.id ? 1.5 : 0.5))
        )
        .scaleEffect(dropTarget == topic.id ? 1.03 : 1)
        .animation(.spring(duration: 0.25), value: dropTarget)
        .contentShape(Rectangle())
        .onTapGesture { library.selectTopic(topic.id) }
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
        }
    }
}
