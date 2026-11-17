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
    /// Front-matter lines Anthology does not own (e.g. `tags:` added in Obsidian). Written back verbatim.
    public var extraFrontMatter: [String]
    /// Former titles, so Claude can still find a note by the name it used before a rename.
    public var aliases: [String]

    public init(meta: NoteMeta, body: String, extraFrontMatter: [String] = [], aliases: [String] = []) {
        self.meta = meta
        self.body = body
        self.extraFrontMatter = extraFrontMatter
        self.aliases = aliases
    }

    public func serialize() -> String {
        """
        ---
        id: \(meta.id)
        title: \(Self.quote(meta.title))
        created: \(MarginDate.format(meta.created))
        updated: \(MarginDate.format(meta.updated))
        revision: \(meta.revision)

        """ + (aliases.isEmpty ? "" : "aliases: \(Self.quoteList(aliases))\n") + extraFrontMatter.map { $0 + "\n" }.joined() + "---\n" + body
    }

    public static func parse(_ raw: String) throws -> NoteFile {
        let text = normalize(raw)
        guard text.hasPrefix("---\n") else { throw MarginError.malformedNote("missing front matter") }
        let afterOpen = text.index(text.startIndex, offsetBy: 4)
        guard let close = text.range(of: "\n---\n", range: afterOpen..<text.endIndex)
                ?? (text.hasSuffix("\n---") ? text.range(of: "\n---", options: .backwards) : nil)
        else { throw MarginError.malformedNote("unterminated front matter") }

        let ownKeys: Set<String> = ["id", "title", "created", "updated", "revision", "aliases"]
        var fields: [String: String] = [:]
        var extra: [String] = []
        for line in text[afterOpen..<close.lowerBound].split(separator: "\n", omittingEmptySubsequences: false) {
            if let colon = line.firstIndex(of: ":") {
                let key = line[..<colon].trimmingCharacters(in: .whitespaces)
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                // Only claim `aliases` when it is Anthology's JSON list; other tools' YAML stays untouched.
                let isOurs = key != "aliases" || (value.hasPrefix("[\"") || value == "[]") && !unquoteList(value).isEmpty || value == "[]"
                if ownKeys.contains(key), isOurs, fields[key] == nil, !line.hasPrefix(" ") {
                    fields[key] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                    continue
                }
            }
            if !line.isEmpty { extra.append(String(line)) }
        }
        guard let id = fields["id"], !id.isEmpty,
              let rawTitle = fields["title"],
              let created = fields["created"].flatMap(MarginDate.parse),
              let updated = fields["updated"].flatMap(MarginDate.parse),
              let revision = fields["revision"].flatMap({ Int($0) })
        else { throw MarginError.malformedNote("missing or invalid keys") }

        let meta = NoteMeta(id: id, title: unquote(rawTitle), created: created, updated: updated, revision: revision)
        let aliases = fields["aliases"].map(unquoteList) ?? []
        return NoteFile(meta: meta, body: String(text[close.upperBound...]), extraFrontMatter: extra, aliases: aliases)
    }

    /// Strips a UTF-8 BOM and converts CRLF line endings to LF.
    static func normalize(_ text: String) -> String {
        var t = text
        if t.hasPrefix("\u{FEFF}") { t.removeFirst() }
        return t.contains("\r\n") ? t.replacingOccurrences(of: "\r\n", with: "\n") : t
    }

    /// Reads a note, or adopts a plain Markdown file (no front matter) as revision 0 with a stable id.
    static func parseOrAdopt(_ text: String, stableKey: String, title: String, date: Date) throws -> NoteFile {
        do {
            return try parse(text)
        } catch MarginError.malformedNote(let why) where why == "missing front matter" {
            let meta = NoteMeta(id: stableID(for: stableKey), title: title, created: date, updated: date, revision: 0)
            return NoteFile(meta: meta, body: normalize(text))
        }
    }

    /// Deterministic 26-char id for adopted files (FNV-1a based, Crockford alphabet, "MD" prefix).
    static func stableID(for key: String) -> String {
        var out = "MD"
        var seed: UInt64 = 0xcbf29ce484222325
        while out.count < 26 {
            var h = seed
            for b in key.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
            for _ in 0..<12 where out.count < 26 {
                out.append(crockford[Int(h % 32)])
                h /= 32
            }
            seed = h &+ 0x9e3779b97f4a7c15
        }
        return out
    }

    static func quote(_ s: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: s, options: [.fragmentsAllowed, .withoutEscapingSlashes])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    static func quoteList(_ items: [String]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: items, options: [.withoutEscapingSlashes])) ?? Data("[]".utf8)
        return String(decoding: data, as: UTF8.self)
    }

    static func unquoteList(_ s: String) -> [String] {
        (try? JSONSerialization.jsonObject(with: Data(s.utf8)) as? [String]) ?? []
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
