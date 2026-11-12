import MarginCore
import SwiftUI

/// ⌘K: search every note; arrow keys + Return to open.
struct SearchPalette: View {
    @Environment(LibraryModel.self) private var library
    @Binding var isPresented: Bool
    @State var query = ""
    @State private var selection = 0
    @FocusState private var focused: Bool

    var body: some View {
        let results = library.search(query)
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color(palette: Palette.tertiary))
                TextField("Search all notes", text: $query)
                    .textFieldStyle(.plain).font(.system(size: 17)).focused($focused)
                    .onKeyPress(.downArrow) { selection = min(selection + 1, max(results.count - 1, 0)); return .handled }
                    .onKeyPress(.upArrow) { selection = max(selection - 1, 0); return .handled }
                    .onKeyPress(.return) { open(results); return .handled }
                    .onKeyPress(.escape) { isPresented = false; return .handled }
                Text("esc").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            .padding(16)
            if !results.isEmpty { Divider().overlay(Color(palette: Palette.hairline)) }
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(results.enumerated()), id: \.offset) { i, hit in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: hit.topic.icon ?? "folder")
                                .foregroundStyle(TopicStyle.color(hit.topic.color)).frame(width: 16)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(hit.topic.title) › \(hit.title)").font(.system(size: 13, weight: .medium))
                                Text(NoteText.plain(hit.snippet)).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(palette: i == selection ? Palette.accentWash : .clear)))
                        .contentShape(Rectangle())
                        .onTapGesture { selection = i; open(results) }
                    }
                }
                .padding(8)
            }
            .frame(height: min(CGFloat(results.count) * 54 + 16, 340))
            .opacity(results.isEmpty ? 0 : 1)
        }
        .frame(width: 600)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(palette: Palette.card)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(palette: Palette.hairline), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 30, y: 12)
        .onAppear { focused = true }
        .onChange(of: query) { selection = 0 }
    }

    private func open(_ results: [LibraryModel.SearchHit]) {
        guard results.indices.contains(selection) else { return }
        library.open(noteID: results[selection].noteID)
        isPresented = false
    }
}
