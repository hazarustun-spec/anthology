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

    var body: some View {
        NavigationStack(path: $path) {
            TopicsScreen(search: search, open: { path.append($0) })
                .navigationTitle("Margin")
                .searchable(text: $search, prompt: Text("Search all notes"))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showCapture = true; Haptics.tap() } label: { Image(systemName: "square.and.pencil") }
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .topic(let id): NotesScreen(topicID: id, open: { path.append($0) })
                    case .note(let id): NoteScreen(noteID: id)
                    }
                }
        }
        .sheet(isPresented: $showCapture) { CaptureSheet().presentationDetents([.height(300), .medium]) }
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

struct TopicsScreen: View {
    @Environment(LibraryModel.self) private var library
    let search: String
    let open: (Route) -> Void

    var body: some View {
        ScrollView {
            if !search.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(library.search(search), id: \.noteID) { hit in
                        Button { open(.note(hit.noteID)) } label: {
                            Card(fresh: false) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(hit.topic.title) › \(hit.title)").font(.subheadline.weight(.semibold))
                                    Text(NoteText.plain(hit.snippet)).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            } else {
                if !library.activity.isEmpty { recent }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(library.topics) { topic in
                        Button { open(.topic(topic.id)); Haptics.tap() } label: { TopicTile(topic: topic) }
                            .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color(palette: Palette.canvas))
        .overlay {
            if library.topics.isEmpty {
                ContentUnavailableView("No notes yet", systemImage: "sparkles",
                    description: Text("Ask Claude to save something to Margin on your Mac. It appears here in seconds."))
            }
        }
        .refreshable { library.refresh(markChanges: true, sync: true) }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent changes").font(.footnote.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(library.activity.prefix(6)) { item in
                        Button { open(.note(item.noteID)) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Label(item.entry.by.displayName, systemImage: item.entry.by.symbol)
                                    .font(.caption2.weight(.medium)).foregroundStyle(Color(palette: Palette.accent))
                                Text(item.noteTitle).font(.subheadline.weight(.semibold)).lineLimit(1)
                                Text(item.entry.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            .frame(width: 190, height: 92, alignment: .topLeading)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color(palette: library.isFresh(item.noteID) ? Palette.accentWash : Palette.card)))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(palette: Palette.hairline), lineWidth: 0.5))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
    }
}

struct TopicTile: View {
    @Environment(LibraryModel.self) private var library
    let topic: Topic
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: topic.icon ?? "folder.fill").symbolVariant(.fill)
                    .font(.system(size: 18)).foregroundStyle(TopicStyle.color(topic.color))
                Spacer()
                if library.topicHasFresh(topic.id) {
                    Circle().fill(Color(palette: Palette.accent)).frame(width: 8, height: 8)
                }
            }
            Spacer(minLength: 0)
            Text(topic.title).font(.headline).foregroundStyle(Color(palette: Palette.text)).lineLimit(2)
            Text("\(library.notes(for: topic.id).count) notes").font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(height: 118)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(palette: Palette.card)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(palette: Palette.hairline), lineWidth: 0.5))
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
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(palette: fresh ? Palette.accentWash : Palette.card)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(palette: fresh ? Palette.accentBorder : Palette.hairline), lineWidth: fresh ? 1 : 0.5))
    }
}

struct NotesScreen: View {
    @Environment(LibraryModel.self) private var library
    let topicID: String
    let open: (Route) -> Void

    var body: some View {
        let topic = library.topics.first { $0.id == topicID }
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(library.notes(for: topicID), id: \.meta.id) { note in
                    Button { open(.note(note.meta.id)); Haptics.tap() } label: {
                        Card(fresh: library.isFresh(note.meta.id)) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(note.meta.title).font(.headline).foregroundStyle(Color(palette: Palette.text))
                                Text(preview(library.body(for: note.meta.id))).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                                HStack(spacing: 4) {
                                    Text(note.meta.updated, format: .relative(presentation: .named))
                                    if let last = library.lastChange(for: note.meta.id), last.by != .app { Text("· \(last.by.displayName)") }
                                }
                                .font(.caption).foregroundStyle(Color(palette: library.isFresh(note.meta.id) ? Palette.accent : Palette.tertiary))
                            }
                        }
                    }
                    .buttonStyle(PressableStyle())
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
            .padding(16)
            .animation(.spring(duration: 0.4), value: library.freshNotes)
        }
        .background(Color(palette: Palette.canvas))
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

