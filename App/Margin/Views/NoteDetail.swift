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
    @State private var titleDraft = ""
    @State private var attribution: [LineAttribution] = []
    @FocusState private var titleFocused: Bool

    var body: some View {
        let note = library.note(noteID)
        VStack(alignment: .leading, spacing: 0) {
            if conflictRevision != nil { conflictBanner }
            if let warning = library.lastChange(for: noteID), warning.warning == "large-removal", warning.by != .app {
                removalBanner(warning)
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    TextField("Title", text: $titleDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color(palette: Palette.text))
                        .focused($titleFocused)
                        .onSubmit { commitTitle() }
                        .onChange(of: titleFocused) { _, focused in if !focused { commitTitle() } }
                }
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
            NoteEditor(text: $text, freshLines: library.freshLines[noteID] ?? [], attribution: attribution) { _ in scheduleSave() }
                // The author gutter sits in the page margin so text stays aligned with the title.
                .padding(.leading, -AttributionGutter.width)
        }
        .frame(maxWidth: 720, alignment: .leading)
        .padding(.horizontal, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(palette: Palette.card))
        .onAppear(perform: load)
        .onChange(of: note?.meta.revision) { _, _ in externalChange() }
        .onChange(of: library.note(noteID)?.meta.title) { _, new in
            if !titleFocused, let new, new != titleDraft { titleDraft = new }
        }
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
            Text("Claude updated this note while you were typing.").foregroundStyle(.primary)
            Spacer()
            Button("Show Claude's version") { load(); conflictRevision = nil }.buttonStyle(.glass)
            Button("Keep mine") {
                if let rev = conflictRevision { baseRevision = rev }
                conflictRevision = nil
                save()
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 14).padding(.vertical, 9)
        .glassEffect(.regular, in: .capsule)
        .padding(.top, 16)
    }

    private func removalBanner(_ entry: HistoryEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(Color(palette: Palette.accent))
            Text("\(entry.by.displayName) removed most of this note.").foregroundStyle(.primary)
            Spacer()
            Button("Undo") {
                library.restore(noteID: noteID, revision: entry.rev - 1)
                load()
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 14).padding(.vertical, 9)
        .glassEffect(.regular, in: .capsule)
        .padding(.top, 16)
    }

    private func commitTitle() {
        let current = library.note(noteID)?.meta.title ?? ""
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { titleDraft = current; return }
        guard trimmed != current else { return }
        flush()
        library.renameNote(noteID, to: trimmed)
        baseRevision = library.note(noteID)?.meta.revision ?? baseRevision
    }

    private func load() {
        titleDraft = library.note(noteID)?.meta.title ?? ""
        text = library.body(for: noteID)
        baseRevision = library.note(noteID)?.meta.revision ?? 0
        attribution = library.attribution(for: noteID)
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

