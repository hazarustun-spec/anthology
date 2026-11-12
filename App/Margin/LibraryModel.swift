import Foundation
import MarginCore
import Observation

/// Reads the notes folder and keeps the UI in sync with changes made by Claude (via margin-mcp) or iCloud.
@MainActor @Observable
final class LibraryModel {
    private(set) var topics: [Topic] = []
    private(set) var notesByTopic: [String: [NoteRef]] = [:]
    /// Note ids whose revision changed since the app last looked, with the time the change was seen.
    private(set) var recentlyChanged: [String: Date] = [:]
    private(set) var errorMessage: String?

    let store: MarginStore?
    private var knownRevisions: [String: Int] = [:]
    private var fingerprint = ""
    private var timer: Timer?

    init(root: URL = MarginPaths.defaultRoot()) {
        do {
            store = try MarginStore(root: root)
        } catch {
            store = nil
            errorMessage = error.localizedDescription
        }
        reload(markChanges: false)
        // Polling keeps M1 simple and robust; NSFilePresenter/NSMetadataQuery arrive with iCloud in M3.
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reloadIfChanged() }
        }
    }

    func notes(for topicID: String) -> [NoteRef] { notesByTopic[topicID] ?? [] }

    func body(for noteID: String) -> String {
        (try? store?.findNote(id: noteID).1.body) ?? ""
    }

    func history(for noteID: String) -> [HistoryEntry] {
        (try? store?.history(noteID: noteID)) ?? []
    }

    func isRecentlyChanged(_ noteID: String) -> Bool {
        guard let seen = recentlyChanged[noteID] else { return false }
        return Date().timeIntervalSince(seen) < 4
    }

    private func reloadIfChanged() {
        let current = Self.fingerprint(of: store?.root)
        guard current != fingerprint else { return }
        reload(markChanges: true)
    }

    func reload(markChanges: Bool) {
        guard let store else { return }
        fingerprint = Self.fingerprint(of: store.root)
        do {
            topics = try store.listTopics()
            var map: [String: [NoteRef]] = [:]
            let now = Date()
            for topic in topics {
                let notes = try store.listNotes(topicID: topic.id)
                map[topic.id] = notes
                for note in notes {
                    if markChanges, knownRevisions[note.meta.id] != note.meta.revision {
                        recentlyChanged[note.meta.id] = now
                    }
                    knownRevisions[note.meta.id] = note.meta.revision
                }
            }
            notesByTopic = map
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Cheap change detector: paths + modification dates of every file under root.
    private static func fingerprint(of root: URL?) -> String {
        guard let root, let walker = FileManager.default.enumerator(
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
