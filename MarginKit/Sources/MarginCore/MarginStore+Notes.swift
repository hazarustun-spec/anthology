import Foundation

extension MarginStore {
    // MARK: Reading

    public func listNotes(topicID: String) throws -> [NoteRef] {
        lock.lock(); defer { lock.unlock() }
        return try loadNotes(in: topic(id: topicID)).map(\.0).sorted { $0.meta.updated > $1.meta.updated }
    }

    public func findNote(id: String) throws -> (NoteRef, NoteFile) {
        lock.lock(); defer { lock.unlock() }
        guard isValidNoteID(id) else { throw MarginError.noteNotFound(id) }
        for topic in try listTopics() {
            if let hit = try loadNotes(in: topic).first(where: { $0.0.meta.id == id }) { return hit }
        }
        throw MarginError.noteNotFound(id)
    }

    public func findNote(topicID: String, title: String) throws -> (NoteRef, NoteFile)? {
        lock.lock(); defer { lock.unlock() }
        let wanted = searchKey(title)
        return try loadNotes(in: topic(id: topicID)).first { searchKey($0.0.meta.title) == wanted }
    }

    public func history(noteID: String) throws -> [HistoryEntry] {
        lock.lock(); defer { lock.unlock() }
        let (ref, _) = try findNote(id: noteID)
        let url = historyURL(topic: ref.topic, noteID: noteID)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let text = String(decoding: try FileIO.read(url), as: UTF8.self)
        return text.split(separator: "\n").compactMap { try? HistoryEntry.decoder.decode(HistoryEntry.self, from: Data($0.utf8)) }
    }

    public func search(_ query: String, limit: Int = 20) throws -> [(NoteRef, snippet: String)] {
        lock.lock(); defer { lock.unlock() }
        let q = searchKey(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !q.isEmpty else { return [] }
        var hits: [(NoteRef, snippet: String)] = []
        for topic in try listTopics() {
            for (ref, file) in try loadNotes(in: topic) {
                let titleHit = searchKey(ref.meta.title).contains(q)
                let line = file.body.split(separator: "\n").first { searchKey(String($0)).contains(q) }
                guard titleHit || line != nil else { continue }
                let snippet = String((line.map(String.init) ?? String(file.body.prefix(160))).prefix(160))
                hits.append((ref, snippet: snippet))
            }
        }
        return Array(hits.sorted { $0.0.meta.updated > $1.0.meta.updated }.prefix(limit))
    }

    // MARK: Writing

    @discardableResult
    public func createNote(topicID: String, title: String, body: String, by: ChangeSource, summary: String, project: String?) throws -> NoteRef {
        try beginWrite(); defer { endWrite() }
        let topic = try topic(id: topicID)
        let dir = directory(of: topic)
        let base = slugify(singleLine(title))
        var name = "\(base).md"
        var n = 2
        while FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path) {
            name = "\(base)-\(n).md"
            n += 1
        }
        let now = MarginDate.now()
        let file = NoteFile(meta: NoteMeta(id: newID(), title: singleLine(title), created: now, updated: now, revision: 1), body: body)
        let url = dir.appendingPathComponent(name)
        try FileIO.write(Data(file.serialize().utf8), to: url)
        try appendHistory(topic: topic, noteID: file.meta.id, entry: HistoryEntry(rev: 1, at: Date(), by: by, summary: summary, project: project))
        return NoteRef(topic: topic, meta: file.meta, fileURL: url)
    }

    @discardableResult
    public func appendToNote(id: String, text: String, by: ChangeSource, summary: String, project: String?) throws -> NoteRef {
        try beginWrite(); defer { endWrite() }
        let (ref, file) = try findNote(id: id)
        let body = file.body.isEmpty ? text : file.body + "\n\n" + text
        return try write(ref: ref, file: file, newBody: body, by: by, summary: summary, project: project)
    }

    /// Replaces the body. Rejected with `.staleRevision` when the note changed since `baseRevision` was read.
    @discardableResult
    public func updateNote(id: String, baseRevision: Int, body: String, by: ChangeSource, summary: String, project: String?) throws -> NoteRef {
        try beginWrite(); defer { endWrite() }
        let (ref, file) = try findNote(id: id)
        guard file.meta.revision == baseRevision else {
            throw MarginError.staleRevision(expected: baseRevision, actual: file.meta.revision)
        }
        return try write(ref: ref, file: file, newBody: body, by: by, summary: summary, project: project)
    }

    public func deleteNote(id: String) throws {
        try beginWrite(); defer { endWrite() }
        let (ref, _) = try findNote(id: id)
        let trashDir = root.appendingPathComponent(".trash/\(ref.topic.directoryName)", isDirectory: true)
        var dest = trashDir.appendingPathComponent(ref.fileURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path) {
            dest = trashDir.appendingPathComponent("\(ref.meta.id)-\(ref.fileURL.lastPathComponent)")
        }
        try FileIO.move(ref.fileURL, to: dest)
    }

    @discardableResult
    public func moveNote(id: String, toTopicID: String) throws -> NoteRef {
        try beginWrite(); defer { endWrite() }
        let (ref, _) = try findNote(id: id)
        let target = try topic(id: toTopicID)
        guard target.id != ref.topic.id else { return ref }
        let dir = directory(of: target)
        let base = ref.fileURL.deletingPathExtension().lastPathComponent
        var dest = dir.appendingPathComponent("\(base).md")
        var n = 2
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = dir.appendingPathComponent("\(base)-\(n).md")
            n += 1
        }
        try FileIO.move(ref.fileURL, to: dest)
        let oldVersions = versionURL(topic: ref.topic, noteID: id, revision: 0).deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: oldVersions.path) {
            try FileIO.move(oldVersions, to: versionURL(topic: target, noteID: id, revision: 0).deletingLastPathComponent())
        }
        let oldHistory = historyURL(topic: ref.topic, noteID: id)
        if FileManager.default.fileExists(atPath: oldHistory.path) {
            try FileIO.move(oldHistory, to: historyURL(topic: target, noteID: id))
        }
        return NoteRef(topic: target, meta: ref.meta, fileURL: dest)
    }

    // MARK: Internals

    private func write(ref: NoteRef, file: NoteFile, newBody: String, by: ChangeSource, summary: String, project: String?) throws -> NoteRef {
        // Keep the body being replaced, so no update (e.g. a prompt-injected one) is ever unrecoverable.
        try FileIO.write(Data(file.body.utf8), to: versionURL(topic: ref.topic, noteID: file.meta.id, revision: file.meta.revision))
        var updated = file
        updated.body = newBody
        updated.meta.revision += 1
        updated.meta.updated = MarginDate.now()
        try FileIO.write(Data(updated.serialize().utf8), to: ref.fileURL)
        try appendHistory(
            topic: ref.topic, noteID: updated.meta.id,
            entry: HistoryEntry(rev: updated.meta.revision, at: Date(), by: by, summary: summary, project: project)
        )
        return NoteRef(topic: ref.topic, meta: updated.meta, fileURL: ref.fileURL)
    }

    func loadNotes(in topic: Topic) throws -> [(NoteRef, NoteFile)] {
        let dir = directory(of: topic)
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey], options: [.skipsHiddenFiles])) ?? []
        return files.filter { url in
            // Never follow symlinks out of the notes folder.
            let v = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
            return url.pathExtension.lowercased() == "md" && v?.isSymbolicLink != true && v?.isRegularFile == true
        }.compactMap { url in
            guard let data = try? FileIO.read(url) else { return nil }
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            do {
                let file = try NoteFile.parseOrAdopt(
                    String(decoding: data, as: UTF8.self),
                    stableKey: "\(topic.directoryName)/\(url.lastPathComponent)",
                    title: url.deletingPathExtension().lastPathComponent,
                    date: Date(timeIntervalSince1970: modified.timeIntervalSince1970.rounded(.down))
                )
                var adopted = file
                // An id from disk becomes part of file paths: anything unexpected is replaced by a stable safe id.
                if !isValidNoteID(adopted.meta.id) {
                    adopted.meta.id = NoteFile.stableID(for: "\(topic.directoryName)/\(url.lastPathComponent)#id")
                }
                return (NoteRef(topic: topic, meta: adopted.meta, fileURL: url), adopted)
            } catch {
                FileHandle.standardError.write(Data("[margin] skipping unreadable note \(url.path): \(error)\n".utf8))
                return nil
            }
        }
    }

    func versionURL(topic: Topic, noteID: String, revision: Int) -> URL {
        directory(of: topic).appendingPathComponent(".history/\(noteID).versions/\(revision).md")
    }

    /// Previous bodies of a note, oldest first.
    public func versions(noteID: String) throws -> [(revision: Int, body: String)] {
        lock.lock(); defer { lock.unlock() }
        let (ref, _) = try findNote(id: noteID)
        let dir = versionURL(topic: ref.topic, noteID: noteID, revision: 0).deletingLastPathComponent()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return names.compactMap { name -> (Int, String)? in
            guard name.hasSuffix(".md"), let rev = Int(name.dropLast(3)),
                  let data = try? FileIO.read(dir.appendingPathComponent(name)) else { return nil }
            return (rev, String(decoding: data, as: UTF8.self))
        }.sorted { $0.0 < $1.0 }.map { (revision: $0.0, body: $0.1) }
    }

    /// Writes an earlier version back as a new revision (history is kept, nothing is lost).
    @discardableResult
    public func restore(noteID: String, revision: Int, by: ChangeSource) throws -> NoteRef {
        try beginWrite(); defer { endWrite() }
        guard let version = try versions(noteID: noteID).first(where: { $0.revision == revision }) else {
            throw MarginError.noteNotFound("\(noteID)@\(revision)")
        }
        let (ref, file) = try findNote(id: noteID)
        return try write(ref: ref, file: file, newBody: version.body, by: by, summary: "Restored revision \(revision)", project: nil)
    }

    func historyURL(topic: Topic, noteID: String) -> URL {
        directory(of: topic).appendingPathComponent(".history/\(noteID).jsonl")
    }

    private func appendHistory(topic: Topic, noteID: String, entry: HistoryEntry) throws {
        let url = historyURL(topic: topic, noteID: noteID)
        var existing = FileManager.default.fileExists(atPath: url.path) ? try FileIO.read(url) : Data()
        var entry = entry
        entry.summary = singleLine(entry.summary)
        existing.append(try HistoryEntry.encoder.encode(entry))
        existing.append(0x0A)
        try FileIO.write(existing, to: url)
    }
}

/// Case-, diacritic- and Turkish-insensitive comparison key ("TASARIMI" == "tasarımı").
func searchKey(_ s: String) -> String {
    let turkish: [Character: Character] = ["İ": "i", "I": "i", "ı": "i"]
    return String(s.map { turkish[$0] ?? $0 })
        .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        .lowercased()
}


/// Note ids Margin generates: 26 Crockford base32 characters. Anything else is never used in a path.
public func isValidNoteID(_ id: String) -> Bool {
    id.count == 26 && id.unicodeScalars.allSatisfy { ("0"..."9").contains($0) || ("A"..."Z").contains($0) }
}

/// Collapses newlines and control characters so titles and summaries stay one line.
func singleLine(_ s: String) -> String {
    let cleaned = s.unicodeScalars.map { CharacterSet.controlCharacters.contains($0) || CharacterSet.newlines.contains($0) ? " " : String($0) }.joined()
    return cleaned.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
}
