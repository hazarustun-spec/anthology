import Foundation
import MarginCore
import Observation

/// Everything the UI shows, loaded off the main thread in one pass.
struct LibrarySnapshot: Sendable {
    var topics: [Topic] = []
    var notesByTopic: [String: [NoteRef]] = [:]
    var bodies: [String: String] = [:]
    var activity: [ActivityItem] = []
}

/// Reads the notes folder, keeps the UI in sync with changes from Claude (margin-mcp) or iCloud,
/// and saves the user's edits.
@MainActor @Observable
final class LibraryModel {
    private(set) var snapshot = LibrarySnapshot()
    /// Note id → time a change from outside the app was noticed (drives the amber wash).
    private(set) var freshNotes: [String: Date] = [:]
    /// Note id → line strings Claude just added (drives the "new" highlight in the editor).
    private(set) var freshLines: [String: Set<String>] = [:]
    private(set) var errorMessage: String?

    var selectedTopicID: String?
    var selectedNoteID: String?

    let store: MarginStore?
    private var fingerprint = ""
    private var loading = false
    private var timer: Timer?
    /// Revisions written by this app, so our own saves are not flagged as "fresh".
    private var ownRevisions: [String: Int] = [:]

    init(root: URL = MarginPaths.defaultRoot()) {
        do {
            store = try MarginStore(root: root)
        } catch {
            store = nil
            errorMessage = error.localizedDescription
        }
        refresh(markChanges: false)
        // Polling keeps M1/M2 simple and robust; NSFilePresenter arrives with iCloud in M3.
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshIfChanged() }
        }
    }

    // MARK: Queries

    var topics: [Topic] { snapshot.topics }
    func notes(for topicID: String?) -> [NoteRef] { topicID.flatMap { snapshot.notesByTopic[$0] } ?? [] }
    func body(for noteID: String) -> String { snapshot.bodies[noteID] ?? "" }
    var activity: [ActivityItem] { snapshot.activity }

    func note(_ id: String?) -> NoteRef? {
        guard let id else { return nil }
        return snapshot.notesByTopic.values.lazy.flatMap { $0 }.first { $0.meta.id == id }
    }

    func lastChange(for noteID: String) -> HistoryEntry? {
        snapshot.activity.first { $0.noteID == noteID }?.entry
            ?? (try? store?.history(noteID: noteID).last) ?? nil
    }

    func history(for noteID: String) -> [HistoryEntry] {
        ((try? store?.history(noteID: noteID)) ?? []).reversed()
    }

    func isFresh(_ noteID: String) -> Bool {
        guard let seen = freshNotes[noteID] else { return false }
        return Date().timeIntervalSince(seen) < 6
    }

    func topicHasFresh(_ topicID: String) -> Bool {
        notes(for: topicID).contains { isFresh($0.meta.id) }
    }

    // MARK: Navigation

    func open(noteID: String) {
        guard let ref = note(noteID) else { return }
        selectedTopicID = ref.topic.id
        selectedNoteID = noteID
    }

    func selectTopic(_ id: String?) {
        selectedTopicID = id
        selectedNoteID = notes(for: id).first?.meta.id
    }

    // MARK: Editing

    enum SaveResult { case saved(Int), stale(Int), failed(String) }

    /// Saves the user's text. Never overwrites a newer revision: returns `.stale` instead.
    func save(noteID: String, baseRevision: Int, body: String) -> SaveResult {
        guard let store else { return .failed("No notes folder") }
        do {
            let ref = try store.updateNote(id: noteID, baseRevision: baseRevision, body: body, by: .app, summary: String(localized: "Edited in Margin"), project: nil)
            ownRevisions[noteID] = ref.meta.revision
            snapshot.bodies[noteID] = body
            refresh(markChanges: true)
            return .saved(ref.meta.revision)
        } catch MarginError.staleRevision(_, let actual) {
            return .stale(actual)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    @discardableResult
    func createNote(in topicID: String) -> String? {
        guard let store else { return nil }
        let ref = try? store.createNote(topicID: topicID, title: String(localized: "Untitled"), body: "", by: .app, summary: String(localized: "Created in Margin"), project: nil)
        guard let ref else { return nil }
        ownRevisions[ref.meta.id] = ref.meta.revision
        refresh(markChanges: false, sync: true)
        selectedTopicID = topicID
        selectedNoteID = ref.meta.id
        return ref.meta.id
    }

    func createTopic(title: String) {
        guard let store, let topic = try? store.createTopic(title: title, source: nil) else { return }
        refresh(markChanges: false, sync: true)
        selectTopic(topic.id)
    }

    func renameTopic(_ id: String, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        _ = try? store?.renameTopic(id: id, title: trimmed)
        refresh(markChanges: false, sync: true)
    }

    func deleteNote(_ id: String) {
        try? store?.deleteNote(id: id)
        if selectedNoteID == id { selectedNoteID = nil }
        refresh(markChanges: false, sync: true)
        if selectedNoteID == nil { selectedNoteID = notes(for: selectedTopicID).first?.meta.id }
    }

    func clearFreshLines(_ noteID: String) { freshLines[noteID] = nil }

    /// Puts back the body a change replaced. `revision` is the revision that existed before that change.
    func restore(noteID: String, revision: Int) {
        guard let store, let ref = try? store.restore(noteID: noteID, revision: revision, by: .app) else { return }
        ownRevisions[noteID] = ref.meta.revision
        refresh(markChanges: false, sync: true)
    }

    func hasVersion(noteID: String, revision: Int) -> Bool {
        ((try? store?.versions(noteID: noteID)) ?? []).contains { $0.revision == revision }
    }

    // MARK: Loading

    private func refreshIfChanged() {
        guard let root = store?.root, !loading else { return }
        loading = true
        Task.detached(priority: .utility) {
            let current = Self.fingerprint(of: root)
            await MainActor.run {
                self.loading = false
                if current != self.fingerprint { self.refresh(markChanges: true) }
            }
        }
    }

    func refresh(markChanges: Bool, sync: Bool = false) {
        guard let store else { return }
        let load: @Sendable () -> (LibrarySnapshot, String) = {
            var snap = LibrarySnapshot()
            snap.topics = (try? store.listTopics()) ?? []
            for topic in snap.topics {
                let notes = (try? store.listNotes(topicID: topic.id)) ?? []
                snap.notesByTopic[topic.id] = notes
                for note in notes {
                    snap.bodies[note.meta.id] = (try? store.findNote(id: note.meta.id).1.body) ?? ""
                }
            }
            snap.activity = (try? store.recentActivity(limit: 12)) ?? []
            return (snap, Self.fingerprint(of: store.root))
        }
        if sync {
            let (snap, print) = load()
            apply(snap, fingerprint: print, markChanges: markChanges)
        } else {
            Task.detached(priority: .userInitiated) {
                let (snap, print) = load()
                await MainActor.run { self.apply(snap, fingerprint: print, markChanges: markChanges) }
            }
        }
    }

    private func apply(_ new: LibrarySnapshot, fingerprint: String, markChanges: Bool) {
        let old = snapshot
        if markChanges {
            let now = Date()
            for note in new.notesByTopic.values.joined() {
                let id = note.meta.id
                let oldRev = old.notesByTopic.values.joined().first { $0.meta.id == id }?.meta.revision
                guard oldRev != note.meta.revision, ownRevisions[id] != note.meta.revision else { continue }
                freshNotes[id] = now
                let before = Set((old.bodies[id] ?? "").split(separator: "\n").map(String.init))
                let added = Set((new.bodies[id] ?? "").split(separator: "\n").map(String.init)).subtracting(before)
                freshLines[id] = added.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            }
        }
        snapshot = new
        self.fingerprint = fingerprint
        if selectedTopicID == nil || !new.topics.contains(where: { $0.id == selectedTopicID }) {
            selectedTopicID = new.topics.first?.id
        }
        if selectedNoteID == nil || note(selectedNoteID) == nil {
            selectedNoteID = notes(for: selectedTopicID).first?.meta.id
        }
        errorMessage = nil
    }

    /// Cheap change detector: paths + modification dates of every file under root.
    nonisolated static func fingerprint(of root: URL) -> String {
        guard let walker = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: []
        ) else { return "" }
        var parts: [String] = []
        for case let url as URL in walker {
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)?.timeIntervalSince1970 ?? 0
            parts.append("\(url.path)|\(date)")
        }
        return parts.sorted().joined(separator: "\n")
    }
}
