import Foundation

enum FileIO {
    /// Coordinated, atomic write. Refuses to write over a file with unresolved iCloud conflicts.
    static func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path),
           let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url), !conflicts.isEmpty {
            throw MarginError.conflict(url.path)
        }
        var coordError: NSError?
        var writeError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { target in
            do { try data.write(to: target, options: .atomic) } catch { writeError = error }
        }
        if let e = coordError ?? writeError { throw e }
    }

    static func read(_ url: URL) throws -> Data {
        var coordError: NSError?
        var result: Result<Data, Error> = .failure(MarginError.noteNotFound(url.path))
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordError) { target in
            result = Result { try Data(contentsOf: target) }
        }
        if let coordError { throw coordError }
        return try result.get()
    }

    static func move(_ from: URL, to: URL) throws {
        try FileManager.default.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
        var coordError: NSError?
        var moveError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(
            writingItemAt: from, options: .forMoving, writingItemAt: to, options: .forReplacing, error: &coordError
        ) { src, dst in
            do { try FileManager.default.moveItem(at: src, to: dst) } catch { moveError = error }
        }
        if let e = coordError ?? moveError { throw e }
    }
}
