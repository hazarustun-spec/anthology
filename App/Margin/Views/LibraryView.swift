import MarginCore
import SwiftUI

struct LibraryView: View {
    @Environment(LibraryModel.self) private var library

    var snapshotLayout = false
    @AppStorage(WindowLook.transparentKey) private var transparentWindow = false

    var body: some View {
        if snapshotLayout {
            // Offscreen renders cannot capture the split view's sidebar material; same views, plain stack.
            HStack(spacing: 0) {
                TopicList().frame(width: 220)
                Divider().overlay(Color(palette: Palette.hairline))
                NoteList().frame(width: 280)
                Divider().overlay(Color(palette: Palette.hairline))
                detail
            }
        } else {
            split
                .overlay(alignment: .top) {
                    if library.showSearch {
                        ZStack(alignment: .top) {
                            Color.black.opacity(0.08).ignoresSafeArea().onTapGesture { library.showSearch = false }
                            SearchPalette(isPresented: Bindable(library).showSearch).padding(.top, 70)
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.spring(duration: 0.3), value: library.showSearch)
        }
    }

    private var split: some View {
        NavigationSplitView {
            TopicList()
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 300)
        } content: {
            NoteList()
                .navigationSplitViewColumnWidth(min: 240, ideal: 290, max: 380)
                .navigationTitle(library.topics.first { $0.id == library.selectedTopicID }?.title ?? "Anthology")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { if let t = library.selectedTopicID { library.createNote(in: t) } } label: {
                            Label("New Note", systemImage: "square.and.pencil")
                        }
                        .help("New note (⌘N)")
                    }
                }
        } detail: {
            detail
                .toolbar {
                    ToolbarSpacer(.flexible, placement: .primaryAction)
                    ToolbarItemGroup(placement: .primaryAction) {
                        AppearanceToggle()
                        Button { QuickCaptureController.shared.show() } label: { Label("Quick Note", systemImage: "text.append") }
                            .help("Quick note (⌥⌘M)")
                        Button { library.showSearch = true } label: { Label("Search Notes", systemImage: "magnifyingglass") }
                            .help("Search all notes (⌘K)")
                    }
                    ToolbarSpacer(.fixed, placement: .primaryAction)
                    ToolbarItem(placement: .primaryAction) {
                        if let note = library.note(library.selectedNoteID) {
                            Menu { NoteMenu(note: note) } label: { Label("More", systemImage: "ellipsis") }
                                .menuIndicator(.hidden)
                        }
                    }
                }
        }
        .containerBackground(for: .window) { WindowBackdrop() }
        .background(WindowConfigurator(transparent: transparentWindow))
    }

    @ViewBuilder
    private var detail: some View {
        if let id = library.selectedNoteID, library.note(id) != nil {
            NoteDetail(noteID: id).id(id)
        } else {
            EmptyState(symbol: "text.alignleft", title: "No note selected", message: "Pick a note, or ask Claude to save something to Anthology.")
        }
    }
}

struct EmptyState: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 26, weight: .light)).foregroundStyle(.tertiary)
            Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary)
            Text(message).font(.callout).foregroundStyle(.tertiary).multilineTextAlignment(.center).frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
