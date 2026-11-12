import Foundation

/// The other device's version of a note, when iCloud could not merge two edits.
public struct ConflictVersion: Sendable {
    public var body: String
    public var modified: Date?
    public var deviceName: String?
    let version: NSFileVersion

    public init(body: String, modified: Date?, deviceName: String?, version: NSFileVersion) {
        self.body = body
        self.modified = modified
        self.deviceName = deviceName
        self.version = version
    }
}

extension NSFileVersion: @retroactive @unchecked Sendable {}

public enum ConflictChoice: Sendable { case keepCurrent, keepOther, keepBoth }

extension MarginStore {
    public func conflicts(noteID: String) throws -> [ConflictVersion] {
        let (ref, _) = try findNote(id: noteID)
        let versions = NSFileVersion.unresolvedConflictVersionsOfItem(at: ref.fileURL) ?? []
        return versions.compactMap { v in
            guard let data = try? Data(contentsOf: v.url),
                  let file = try? NoteFile.parse(String(decoding: data, as: UTF8.self)) else { return nil }
            return ConflictVersion(body: file.body, modified: v.modificationDate, deviceName: v.localizedNameOfSavingComputer, version: v)
        }
    }

    public func notesWithConflicts() throws -> [NoteRef] {
        try listTopics().flatMap { try listNotes(topicID: $0.id) }.filter {
            !(NSFileVersion.unresolvedConflictVersionsOfItem(at: $0.fileURL) ?? []).isEmpty
        }
    }

    /// Nothing is thrown away: "keep current/other" saves the losing text as a version (Undo-able),
    /// "keep both" adds the other text as a new note "<title> (conflict copy)".
    public func resolveConflict(noteID: String, choice: ConflictChoice, by: ChangeSource) throws {
        try beginWrite(); defer { endWrite() }
        let (ref, file) = try findNote(id: noteID)
        let others = try conflicts(noteID: noteID)
        guard let other = others.first else { return }
        let markResolved = {
            for v in NSFileVersion.unresolvedConflictVersionsOfItem(at: ref.fileURL) ?? [] { v.isResolved = true }
            try NSFileVersion.removeOtherVersionsOfItem(at: ref.fileURL)
        }
        switch choice {
        case .keepCurrent:
            try FileIO.write(Data(other.body.utf8), to: versionURL(topic: ref.topic, noteID: noteID, revision: file.meta.revision * 1000 + 1))
            try markResolved()
        case .keepOther:
            try markResolved()
            try updateNote(id: noteID, baseRevision: file.meta.revision, body: other.body, by: by, summary: "Kept the other device's version", project: nil)
        case .keepBoth:
            try markResolved()
            try createNote(topicID: ref.topic.id, title: "\(file.meta.title) (conflict copy)", body: other.body, by: by, summary: "Conflict copy from another device", project: nil)
        }
    }
}
