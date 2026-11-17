import MarginCore
import SwiftUI

enum Route: Hashable {
    case topic(String)
    case note(String)
}

struct RootView: View {
    @Environment(LibraryModel.self) private var library
    @State private var path: [Route] = []
    @State private var search = ""
    @State private var showCapture = false
    @State private var showSettings = false
    @Namespace private var glass

    var body: some View {
        NavigationStack(path: $path) {
            TopicsScreen(search: search, open: { path.append($0) })
                .navigationTitle("Anthology")
                .searchable(text: $search, prompt: Text("Search all notes"))
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        AppearanceToggle()
                        Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    }
                    // Notes / Craft pattern: search field and a prominent compose button share the bottom bar.
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    ToolbarItem(placement: .bottomBar) {
                        Button { showCapture = true; Haptics.tap() } label: { Image(systemName: "square.and.pencil") }
                            .buttonStyle(.glassProminent)
                            .tint(Color(palette: Palette.accent))
                    }
                    .matchedTransitionSource(id: "capture", in: glass)
                }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .topic(let id): NotesScreen(topicID: id, open: { path.append($0) })
                    case .note(let id): NoteScreen(noteID: id)
                    }
                }
        }
        .sheet(isPresented: $showCapture) {
            CaptureSheet()
                .presentationDetents([.height(300), .medium])
                .navigationTransition(.zoom(sourceID: "capture", in: glass))
        }
        #if DEBUG
        .task {
            // Screenshot helper: `-openNote <id>` pushes a note on launch (debug builds only).
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-openNote"), i + 1 < args.count {
                try? await Task.sleep(for: .milliseconds(600))
                if let ref = library.note(args[i + 1]) { path = [.topic(ref.topic.id), .note(ref.meta.id)] }
            }
        }
        #endif
        .sheet(isPresented: $showSettings) { MobileSettings() }
    }
}

/// Home: a plain inset list like Notes — recent changes on top, then topics.
struct TopicsScreen: View {
    @Environment(LibraryModel.self) private var library
    let search: String
    let open: (Route) -> Void

    var body: some View {
        List {
            if !search.isEmpty {
                ForEach(library.search(search), id: \.noteID) { hit in
                    row {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(hit.title).font(.body.weight(.medium)).foregroundStyle(Color(palette: Palette.text))
                            Text("\(hit.topic.title) · \(NoteText.plain(hit.snippet))").font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                        }
                    } action: { open(.note(hit.noteID)) }
                }
            } else {
                if !recentItems.isEmpty {
                    Section("Recent changes") {
                        ForEach(recentItems) { item in
                            row {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.noteTitle).font(.body.weight(.medium)).foregroundStyle(Color(palette: Palette.text)).lineLimit(1)
                                    HStack(spacing: 4) {
                                        Text(item.entry.by.displayName)
                                        Text("·")
                                        Text(item.entry.at, format: .relative(presentation: .named))
                                    }
                                    .font(.footnote).foregroundStyle(.secondary)
                                }
                            } action: { open(.note(item.noteID)) }
                        }
                    }
                }
                Section("Topics") {
                    ForEach(library.topics) { topic in
                        row {
                            HStack(spacing: 12) {
                                Image(systemName: topic.icon ?? "folder").font(.system(size: 17))
                                    .foregroundStyle(TopicStyle.color(topic.color)).frame(width: 24)
                                Text(topic.title).foregroundStyle(Color(palette: Palette.text)).lineLimit(1)
                                Spacer()
                                if library.topicHasFresh(topic.id) {
                                    Circle().fill(Color(palette: Palette.accent)).frame(width: 7, height: 7)
                                }
                                Text("\(library.notes(for: topic.id).count)").foregroundStyle(.secondary)
                            }
                        } action: { open(.topic(topic.id)) }
                        .contextMenu {
                            Button("Move to Trash", systemImage: "trash", role: .destructive) { library.trashTopic(topic.id) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(palette: Palette.canvas).ignoresSafeArea())
        .overlay {
            if library.topics.isEmpty {
                ContentUnavailableView("No notes yet", systemImage: "sparkles",
                    description: Text("Ask Claude to save something to Anthology on your Mac. It appears here in seconds."))
            }
        }
        .refreshable { library.refresh(markChanges: true, sync: true) }
    }

    /// Latest change per note, newest first, at most three.
    private var recentItems: [ActivityItem] {
        var seen = Set<String>()
        return Array(library.activity.filter { seen.insert($0.noteID).inserted }.prefix(3))
    }

    private func row<Label: View>(@ViewBuilder _ label: () -> Label, action: @escaping () -> Void) -> some View {
        Button { action(); Haptics.tap() } label: {
            HStack { label(); Spacer(minLength: 8); Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color(palette: Palette.card))
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

struct Card<Content: View>: View {
    let fresh: Bool
    @ViewBuilder let content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .card(cornerRadius: 14, fresh: fresh)
    }
}

struct NotesScreen: View {
    @Environment(LibraryModel.self) private var library
    let topicID: String
    let open: (Route) -> Void

    var body: some View {
        let topic = library.topics.first { $0.id == topicID }
        List {
            ForEach(library.notes(for: topicID), id: \.meta.id) { note in
                Button { open(.note(note.meta.id)); Haptics.tap() } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(note.meta.title).font(.body.weight(.semibold)).foregroundStyle(Color(palette: Palette.text)).lineLimit(1)
                        HStack(spacing: 6) {
                            Text(note.meta.updated, format: .relative(presentation: .named))
                            Text(preview(library.body(for: note.meta.id))).lineLimit(1)
                        }
                        .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color(palette: library.isFresh(note.meta.id) ? Palette.accentWash : Palette.card))
                .swipeActions {
                    Button("Move to Trash", systemImage: "trash", role: .destructive) { library.deleteNote(note.meta.id) }
                }
                .contextMenu {
                    Button("Copy as Markdown", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = "# \(note.meta.title)\n\n\(library.body(for: note.meta.id))"
                        Haptics.success()
                    }
                    Menu("Move to", systemImage: "folder") {
                        ForEach(library.topics.filter { $0.id != topicID }) { t in Button(t.title) { library.moveNote(note.meta.id, to: t.id) } }
                    }
                    Button("Move to Trash", systemImage: "trash", role: .destructive) { library.deleteNote(note.meta.id) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .animation(.spring(duration: 0.4), value: library.freshNotes)
        .background(Color(palette: Palette.canvas).ignoresSafeArea())
        .navigationTitle(topic?.title ?? "")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { if let id = library.createNote(in: topicID) { open(.note(id)) } } label: { Image(systemName: "plus") }
            }
        }
        .refreshable { library.refresh(markChanges: true, sync: true) }
    }

    private func preview(_ body: String) -> String {
        body.split(separator: "\n").map { NoteText.plain(String($0)) }.filter { !$0.isEmpty }.prefix(3).joined(separator: " · ")
    }
}

