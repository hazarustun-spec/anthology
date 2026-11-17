import Foundation

/// Who wrote a line and when: derived from the note's saved versions (like `git blame`).
public struct LineAttribution: Equatable, Sendable {
    public var text: String
    public var source: ChangeSource?
    public var revision: Int
    public var date: Date?
}

extension MarginStore {
    public func lineAttribution(noteID: String) throws -> [LineAttribution] {
        let (_, file) = try findNote(id: noteID)
        let history = Dictionary(try history(noteID: noteID).map { ($0.rev, $0) }, uniquingKeysWith: { $1 })
        // Bodies in order: every saved version, then the current body.
        var snapshots = try versions(noteID: noteID).map { ($0.revision, $0.body) }
        snapshots.append((file.meta.revision, file.body))

        func attribute(_ rev: Int) -> (ChangeSource?, Date?) {
            // A version's lines were written by the change that produced that revision.
            if let h = history[rev] { return (h.by, h.at) }
            return (nil, nil)
        }

        var current: [LineAttribution] = []
        for (index, (rev, body)) in snapshots.enumerated() {
            let lines = body.isEmpty ? [] : body.components(separatedBy: "\n")
            let (src, date) = attribute(rev)
            if index == 0 {
                current = lines.map { LineAttribution(text: $0, source: src, revision: rev, date: date) }
                continue
            }
            let matches = Self.lcsMatches(current.map(\.text), lines)
            current = lines.enumerated().map { i, text in
                if let j = matches[i] { return current[j] }
                return LineAttribution(text: text, source: src, revision: rev, date: date)
            }
        }
        return current
    }

    /// For each line of `new`, the index of the matching line in `old` (longest common subsequence).
    public static func lcsMatches(_ old: [String], _ new: [String]) -> [Int?] {
        let n = old.count, m = new.count
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                dp[i][j] = old[i] == new[j] ? dp[i + 1][j + 1] + 1 : max(dp[i + 1][j], dp[i][j + 1])
            }
        }
        var result = [Int?](repeating: nil, count: m)
        var i = 0, j = 0
        while i < n && j < m {
            if old[i] == new[j] { result[j] = i; i += 1; j += 1 }
            else if dp[i + 1][j] >= dp[i][j + 1] { i += 1 }
            else { j += 1 }
        }
        return result
    }
}
