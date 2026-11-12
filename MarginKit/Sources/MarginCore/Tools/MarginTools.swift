import Foundation

public enum ToolArg: Equatable, Sendable {
    case string(String)
    case int(Int)
}

public struct ToolResult: Equatable, Sendable {
    public var text: String
    public var isError: Bool
}

public struct ToolParam: Sendable {
    public var name: String
    public var type: String // "string" | "integer"
    public var description: String
    public var required: Bool
}

public struct ToolSpec: Sendable {
    public var name: String
    public var description: String
    public var params: [ToolParam]
}

/// Transport-independent implementation of Margin's MCP tools.
public struct MarginTools: Sendable {
    let store: MarginStore
    let source: ChangeSource
    /// Used when Claude omits `project_path`. Claude Code starts MCP servers in the project folder.
    let defaultProjectPath: String?

    public init(store: MarginStore, source: ChangeSource, defaultProjectPath: String? = nil) {
        self.store = store
        self.source = source
        self.defaultProjectPath = defaultProjectPath.flatMap(Self.usableProjectPath)
    }

    /// A working directory only identifies a project if it is not `/` or the home folder.
    public static func usableProjectPath(_ path: String) -> String? {
        let p = MarginStore.normalize(path) ?? ""
        let home = MarginStore.normalize(NSHomeDirectory()) ?? ""
        return (p.isEmpty || p == "/" || p == home) ? nil : p
    }

    public static let toolSpecs: [ToolSpec] = [
        ToolSpec(name: "list_topics", description: "List all Margin topics with their notes (id, revision, last updated) and the project folders that route to each topic.", params: []),
        ToolSpec(name: "get_note", description: "Read one note's Markdown and its current revision. Identify it by note_id, or by topic title + note title.", params: [
            p("note_id", "Note id from list_topics/search_notes.", required: false),
            p("topic", "Topic title (with `title`).", required: false),
            p("title", "Note title (with `topic`).", required: false),
        ]),
        ToolSpec(name: "search_notes", description: "Full-text search across all notes (case/diacritic-insensitive). Returns matching notes with a snippet.", params: [
            p("query", "Words to search for."),
        ]),
        ToolSpec(name: "save_note", description: "Save something to Margin. Resolves the topic from project_path (or `topic`). If note_title matches an existing note in that topic, the content is appended to it; otherwise a new note is created. To merge into an existing note cleanly, prefer get_note + update_note.", params: [
            p("content", "Markdown to save."),
            p("summary", "One-line description of the change for the note's history."),
            p("project_path", "Absolute path of the current project/working folder.", required: false),
            p("topic", "Explicit topic title; overrides project_path routing.", required: false),
            p("note_title", "Title of the note to create or append to. Defaults to the content's first line.", required: false),
        ]),
        ToolSpec(name: "update_note", description: "Replace a note's Markdown with a merged, updated version. base_revision must be the revision you read with get_note; if the note changed since, the call fails and you must re-read and merge again.", params: [
            p("note_id", "Note id."),
            ToolParam(name: "base_revision", type: "integer", description: "Revision returned by get_note.", required: true),
            p("content", "Full new Markdown body."),
            p("summary", "One-line description of the change for the note's history."),
        ]),
        ToolSpec(name: "rename_topic", description: "Rename a topic. Routing from its project folders keeps working.", params: [
            p("topic_id", "Topic id."), p("title", "New title."),
        ]),
        ToolSpec(name: "move_note", description: "Move a note to another topic.", params: [
            p("note_id", "Note id."), p("topic_id", "Destination topic id."),
        ]),
        ToolSpec(name: "delete_note", description: "Move a note to Margin's trash. Only when the user asks.", params: [
            p("note_id", "Note id."),
        ]),
    ]

    private static func p(_ name: String, _ description: String, required: Bool = true) -> ToolParam {
        ToolParam(name: name, type: "string", description: description, required: required)
    }

    // MARK: Dispatch

    public func call(_ name: String, _ args: [String: ToolArg]) -> ToolResult {
        do {
            if let spec = Self.toolSpecs.first(where: { $0.name == name }) {
                let missing = spec.params.filter { $0.required && args[$0.name] == nil }.map(\.name)
                if !missing.isEmpty { return .error("Missing required argument(s): \(missing.joined(separator: ", ")).") }
            }
            switch name {
            case "list_topics": return .ok(try listTopics())
            case "get_note": return .ok(try getNote(args))
            case "search_notes": return .ok(try searchNotes(args))
            case "save_note": return .ok(try saveNote(args))
            case "update_note": return .ok(try updateNote(args))
            case "rename_topic":
                let t = try store.renameTopic(id: str(args, "topic_id"), title: str(args, "title"))
                return .ok("Renamed topic to \(t.title).")
            case "move_note":
                let r = try store.moveNote(id: str(args, "note_id"), toTopicID: str(args, "topic_id"))
                return .ok("Moved to \(r.topic.title) › \(r.meta.title).")
            case "delete_note":
                try store.deleteNote(id: str(args, "note_id"))
                return .ok("Moved note to Margin's trash.")
            default: return .error("Unknown tool \(name).")
            }
        } catch let error as MarginError {
            return .error(message(for: error))
        } catch {
            return .error("Margin error: \(error.localizedDescription)")
        }
    }

    private func message(for error: MarginError) -> String {
        switch error {
        case .staleRevision(_, let actual):
            "Note changed since you read it (now revision \(actual)). Call get_note again, merge, and retry."
        case .ambiguousTopic(let titles):
            "Several topics match this project folder: \(titles.joined(separator: ", ")). Ask the user which one, then call again with `topic`."
        case .conflict:
            "This note has two versions from different devices. Ask the user to resolve it in the Margin app first."
        default:
            error.localizedDescription
        }
    }

    // MARK: Tools

    private func listTopics() throws -> String {
        let topics = try store.listTopics()
        if topics.isEmpty { return "No topics yet." }
        return try topics.map { topic in
            var lines = ["\(topic.title) (topic_id=\(topic.id))" + (topic.sources.isEmpty ? "" : " — folders: \(topic.sources.joined(separator: ", "))")]
            for n in try store.listNotes(topicID: topic.id) {
                lines.append("  • \(n.meta.title) (note_id=\(n.meta.id), revision=\(n.meta.revision), updated \(MarginDate.format(n.meta.updated)))")
            }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n")
    }

    private func getNote(_ args: [String: ToolArg]) throws -> String {
        let (ref, file): (NoteRef, NoteFile)
        if let id = optStr(args, "note_id") {
            (ref, file) = try store.findNote(id: id)
        } else if let topicTitle = optStr(args, "topic"), let title = optStr(args, "title") {
            guard let topic = try store.listTopics().first(where: { searchKey($0.title) == searchKey(topicTitle) }) else {
                throw MarginError.topicNotFound(topicTitle)
            }
            guard let hit = try store.findNote(topicID: topic.id, title: title) else { throw MarginError.noteNotFound(title) }
            (ref, file) = hit
        } else {
            return "Pass note_id, or topic + title."
        }
        return "# \(ref.meta.title) · topic=\(ref.topic.title) · note_id=\(ref.meta.id) · revision=\(ref.meta.revision)\n\n\(file.body)"
    }

    private func searchNotes(_ args: [String: ToolArg]) throws -> String {
        let hits = try store.search(str(args, "query"))
        if hits.isEmpty { return "No matching notes." }
        return hits.map { "\($0.0.topic.title) › \($0.0.meta.title) (note_id=\($0.0.meta.id))\n  \($0.snippet)" }.joined(separator: "\n")
    }

    private func saveNote(_ args: [String: ToolArg]) throws -> String {
        let content = try str(args, "content")
        let summary = try str(args, "summary")
        let project = optStr(args, "project_path") ?? defaultProjectPath
        let explicitTopic = optStr(args, "topic")
        var topic = try store.resolveTopic(projectPath: project, explicitTitle: explicitTopic)
        // A topic named explicitly gets its first folder, unless that folder already routes elsewhere.
        if explicitTopic != nil, let project, topic.sources.isEmpty,
           try !store.listTopics().contains(where: { $0.sources.contains(project) }) {
            try store.addSource(topicID: topic.id, source: project)
            topic = try store.topic(id: topic.id)
        }
        let title = optStr(args, "note_title") ?? Self.title(from: content)
        let ref: NoteRef
        if let (existing, _) = try store.findNote(topicID: topic.id, title: title) {
            ref = try store.appendToNote(id: existing.meta.id, text: content, by: source, summary: summary, project: project)
        } else {
            ref = try store.createNote(topicID: topic.id, title: title, body: content, by: source, summary: summary, project: project)
        }
        return "Saved to \(ref.topic.title) › \(ref.meta.title) (note_id=\(ref.meta.id), revision=\(ref.meta.revision))."
    }

    private func updateNote(_ args: [String: ToolArg]) throws -> String {
        let ref = try store.updateNote(
            id: str(args, "note_id"), baseRevision: int(args, "base_revision"),
            body: str(args, "content"), by: source, summary: str(args, "summary"), project: nil
        )
        return "Updated \(ref.topic.title) › \(ref.meta.title) (revision=\(ref.meta.revision))."
    }

    static func title(from content: String) -> String {
        let first = content.split(separator: "\n").first.map(String.init) ?? ""
        let stripped = first.drop { $0 == "#" || $0 == " " || $0 == "-" || $0 == "*" }.trimmingCharacters(in: .whitespaces)
        return stripped.isEmpty ? "Note" : String(stripped.prefix(60))
    }

    // MARK: Args

    private struct ArgError: LocalizedError {
        let errorDescription: String?
    }

    private func str(_ a: [String: ToolArg], _ k: String) throws -> String {
        guard let v = optStr(a, k) else { throw ArgError(errorDescription: "Missing required argument: \(k).") }
        return v
    }

    private func optStr(_ a: [String: ToolArg], _ k: String) -> String? {
        switch a[k] {
        case .string(let s): s.isEmpty ? nil : s
        case .int(let i): String(i)
        case nil: nil
        }
    }

    private func int(_ a: [String: ToolArg], _ k: String) throws -> Int {
        switch a[k] {
        case .int(let i): return i
        case .string(let s): if let i = Int(s) { return i }
        case nil: break
        }
        throw ArgError(errorDescription: "Argument \(k) must be an integer.")
    }
}

extension ToolResult {
    static func ok(_ text: String) -> ToolResult { ToolResult(text: text, isError: false) }
    static func error(_ text: String) -> ToolResult { ToolResult(text: text, isError: true) }
}
