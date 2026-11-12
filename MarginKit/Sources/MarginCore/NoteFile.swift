import Foundation

public struct NoteMeta: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var created: Date
    public var updated: Date
    public var revision: Int

    public init(id: String, title: String, created: Date, updated: Date, revision: Int) {
        self.id = id
        self.title = title
        self.created = created
        self.updated = updated
        self.revision = revision
    }
}

/// A note on disk: YAML-style front matter with fixed keys, then the Markdown body verbatim.
public struct NoteFile: Equatable, Sendable {
    public var meta: NoteMeta
    public var body: String

    public init(meta: NoteMeta, body: String) {
        self.meta = meta
        self.body = body
    }

    public func serialize() -> String {
        """
        ---
        id: \(meta.id)
        title: \(Self.quote(meta.title))
        created: \(MarginDate.format(meta.created))
        updated: \(MarginDate.format(meta.updated))
        revision: \(meta.revision)
        ---

        """ + body
    }

    public static func parse(_ text: String) throws -> NoteFile {
        guard text.hasPrefix("---\n") else { throw MarginError.malformedNote("missing front matter") }
        let afterOpen = text.index(text.startIndex, offsetBy: 4)
        guard let close = text.range(of: "\n---\n", range: afterOpen..<text.endIndex)
                ?? (text.hasSuffix("\n---") ? text.range(of: "\n---", options: .backwards) : nil)
        else { throw MarginError.malformedNote("unterminated front matter") }

        var fields: [String: String] = [:]
        for line in text[afterOpen..<close.lowerBound].split(separator: "\n") {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            fields[key] = value
        }
        guard let id = fields["id"], !id.isEmpty,
              let rawTitle = fields["title"],
              let created = fields["created"].flatMap(MarginDate.parse),
              let updated = fields["updated"].flatMap(MarginDate.parse),
              let revision = fields["revision"].flatMap({ Int($0) })
        else { throw MarginError.malformedNote("missing or invalid keys") }

        let meta = NoteMeta(id: id, title: unquote(rawTitle), created: created, updated: updated, revision: revision)
        return NoteFile(meta: meta, body: String(text[close.upperBound...]))
    }

    static func quote(_ s: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: s, options: [.fragmentsAllowed, .withoutEscapingSlashes])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    static func unquote(_ s: String) -> String {
        guard s.hasPrefix("\""),
              let value = try? JSONSerialization.jsonObject(with: Data(s.utf8), options: .fragmentsAllowed) as? String
        else { return s }
        return value
    }
}

public enum MarginDate {
    /// Current time truncated to whole seconds, so it survives a format/parse round trip.
    public static func now() -> Date { Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down)) }

    public static func format(_ date: Date) -> String {
        date.formatted(.iso8601)
    }

    public static func parse(_ s: String) -> Date? {
        try? Date(s, strategy: .iso8601)
    }
}

private let crockford = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

/// ULID-style identifier: 10 chars of millisecond timestamp + 16 random chars, Crockford base32.
public func newID() -> String {
    var ms = UInt64(Date().timeIntervalSince1970 * 1000)
    var time = [Character](repeating: "0", count: 10)
    for i in stride(from: 9, through: 0, by: -1) {
        time[i] = crockford[Int(ms % 32)]
        ms /= 32
    }
    let random = (0..<16).map { _ in crockford[Int.random(in: 0..<32)] }
    return String(time + random)
}
