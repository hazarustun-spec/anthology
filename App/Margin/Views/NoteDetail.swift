import MarginCore
import SwiftUI

struct NoteDetail: View {
    @Environment(LibraryModel.self) private var library
    let noteID: String

    @State private var text = ""
    @State private var baseRevision = 0
    @State private var dirty = false
    @State private var saveTask: Task<Void, Never>?
    @State private var conflictRevision: Int?
    @State private var showHistory = false

    var body: some View {
        let note = library.note(noteID)
        VStack(alignment: .leading, spacing: 0) {
            if conflictRevision != nil { conflictBanner }
            VStack(alignment: .leading, spacing: 12) {
                Text(note?.meta.title ?? "")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color(palette: Palette.text))
                    .textSelection(.enabled)
                if let last = library.lastChange(for: noteID) {
                    Button { showHistory.toggle() } label: { SourceBadge(entry: last) }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showHistory, arrowEdge: .bottom) {
                            HistoryList(entries: library.history(for: noteID), canRestore: { library.hasVersion(noteID: noteID, revision: $0 - 1) }) { rev in
                                library.restore(noteID: noteID, revision: rev - 1)
                                showHistory = false
                                load()
                            }
                        }
                }
            }
            .padding(.top, 28).padding(.bottom, 8)
            NoteEditor(text: $text, freshLines: library.freshLines[noteID] ?? []) { _ in scheduleSave() }
        }
        .frame(maxWidth: 700, alignment: .leading)
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(palette: Palette.card))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(palette: Palette.hairline), lineWidth: 0.5))
        )
        .padding(14)
        .background(Color(palette: Palette.canvas))
        .onAppear(perform: load)
        .onChange(of: note?.meta.revision) { _, _ in externalChange() }
        .onDisappear { flush() }
        .task(id: library.freshLines[noteID]) {
            guard library.freshLines[noteID] != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            library.clearFreshLines(noteID)
        }
    }

    private var conflictBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles").foregroundStyle(Color(palette: Palette.accent))
            Text("Claude updated this note while you were typing.").foregroundStyle(Color(palette: Palette.text))
            Spacer()
            Button("Show Claude's version") { load(); conflictRevision = nil }
            Button("Keep mine") {
                if let rev = conflictRevision { baseRevision = rev }
                conflictRevision = nil
                save()
            }
        }
        .font(.system(size: 12))
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color(palette: Palette.accentWash)))
        .padding(.top, 16)
    }

    private func load() {
        text = library.body(for: noteID)
        baseRevision = library.note(noteID)?.meta.revision ?? 0
        dirty = false
    }

    private func externalChange() {
        guard let rev = library.note(noteID)?.meta.revision, rev != baseRevision else { return }
        if dirty { conflictRevision = rev } else { load() }
    }

    private func scheduleSave() {
        dirty = true
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            save()
        }
    }

    private func flush() {
        guard dirty else { return }
        saveTask?.cancel()
        save()
    }

    private func save() {
        guard conflictRevision == nil else { return }
        switch library.save(noteID: noteID, baseRevision: baseRevision, body: text) {
        case .saved(let rev): baseRevision = rev; dirty = false
        case .stale(let rev): conflictRevision = rev
        case .failed: break
        }
    }
}

struct SourceBadge: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.by.symbol).foregroundStyle(Color(palette: Palette.accent))
            Text(entry.by.label)
            Text("·")
            Text(entry.summary).lineLimit(1)
            Text("·")
            Text(entry.at, format: .relative(presentation: .named))
            Image(systemName: "chevron.down").font(.system(size: 9))
        }
        .font(.system(size: 12))
        .foregroundStyle(Color(palette: Palette.secondary))
        .padding(.horizontal, 11).padding(.vertical, 5)
        .background(Capsule().fill(Color(palette: Palette.chip)))
    }
}

struct HistoryList: View {
    let entries: [HistoryEntry]
    var canRestore: (Int) -> Bool = { _ in false }
    var onRestore: (Int) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("History").font(.system(size: 13, weight: .semibold)).padding(.bottom, 8)
                ForEach(entries, id: \.rev) { e in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: e.by.symbol).foregroundStyle(Color(palette: e.by == .app ? Palette.secondary : Palette.accent)).frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.summary).foregroundStyle(Color(palette: Palette.text))
                            HStack(spacing: 4) {
                                Text(e.by.label)
                                Text("·")
                                Text(e.at, format: .dateTime.day().month().hour().minute())
                            }
                            .font(.system(size: 11)).foregroundStyle(Color(palette: Palette.tertiary))
                        }
                        Spacer(minLength: 6)
                        if e.rev > 1, canRestore(e.rev) {
                            Button("Undo") { onRestore(e.rev) }
                                .buttonStyle(.plain).font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(palette: Palette.accent))
                                .help("Restore the note as it was before this change")
                        }
                    }
                    .padding(.vertical, 7)
                    Divider().overlay(Color(palette: Palette.hairline))
                }
            }
            .padding(14)
        }
        .font(.system(size: 12))
        .frame(width: 320, height: min(CGFloat(entries.count) * 52 + 50, 360))
        .background(Color(palette: Palette.canvas))
    }
}
