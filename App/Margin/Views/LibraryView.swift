import MarginCore
import SwiftUI

struct LibraryView: View {
    @Environment(LibraryModel.self) private var library

    var snapshotLayout = false

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
                            Color.black.opacity(0.18).ignoresSafeArea().onTapGesture { library.showSearch = false }
                            SearchPalette(isPresented: Bindable(library).showSearch).padding(.top, 90)
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
                .navigationSplitViewColumnWidth(min: 230, ideal: 270, max: 360)
        } detail: {
            detail
        }
        .background(Color(palette: Palette.canvas))
    }

    @ViewBuilder
    private var detail: some View {
        if let id = library.selectedNoteID, library.note(id) != nil {
            NoteDetail(noteID: id).id(id)
        } else {
            EmptyState(symbol: "text.alignleft", title: "No note selected", message: "Pick a note, or ask Claude to save something to Margin.")
        }
    }
}

struct EmptyState: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 26, weight: .light)).foregroundStyle(Color(palette: Palette.tertiary))
            Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(Color(palette: Palette.secondary))
            Text(message).font(.callout).foregroundStyle(Color(palette: Palette.tertiary)).multilineTextAlignment(.center).frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(palette: Palette.canvas))
    }
}
