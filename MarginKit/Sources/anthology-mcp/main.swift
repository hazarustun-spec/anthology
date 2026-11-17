import Foundation
import MarginCore
import MCP

// anthology-mcp: stdio MCP server that lets Claude read and write Anthology notes.
// Usage: anthology-mcp [--source claude-code|cowork] [--root <path>]
// Logs go to stderr only; stdout is the MCP channel.

func log(_ message: String) {
    FileHandle.standardError.write(Data("[anthology-mcp] \(message)\n".utf8))
}

// `anthology-mcp hook`: Claude Code UserPromptSubmit hook (reads the event JSON on stdin).
if CommandLine.arguments.dropFirst().first == "hook" {
    let input = FileHandle.standardInput.readDataToEndOfFile()
    let settings = MarginSettings.load()
    guard let store = try? MarginStore(root: MarginPaths.defaultRoot()) else {
        // An instant capture must never reach the model, even when the notes folder can't be opened.
        if let object = try? JSONSerialization.jsonObject(with: input) as? [String: Any],
           let prompt = object["prompt"] as? String, case .instant = settings.classify(prompt),
           let output = try? JSONSerialization.data(withJSONObject: [
               "decision": "block", "reason": "Anthology couldn't open your notes folder, so this wasn't saved.",
           ]) {
            FileHandle.standardOutput.write(output)
        }
        exit(0)
    }
    let handler = HookHandler(store: store, settings: settings, quickNoteTitle: MarginTools.quickNoteTitle)
    if let output = handler.handle(input) { FileHandle.standardOutput.write(output) }
    exit(0)
}

var source = ChangeSource.claudeCode
var env = ProcessInfo.processInfo.environment
var argv = CommandLine.arguments.dropFirst().makeIterator()
while let arg = argv.next() {
    switch arg {
    case "--source": if let v = argv.next(), let s = ChangeSource(rawValue: v) { source = s }
    case "--root": if let v = argv.next() { env["MARGIN_ROOT"] = v }
    case "--version": print("anthology-mcp \(MarginCore.version)"); exit(0)
    default: log("ignoring unknown argument \(arg)")
    }
}

let root = MarginPaths.defaultRoot(env: env)
let tools: MarginTools
do {
    tools = MarginTools(
        store: try MarginStore(root: root), source: source,
        defaultProjectPath: FileManager.default.currentDirectoryPath,
        liveSettings: { MarginSettings.load() }
    )
} catch {
    log("cannot open notes folder \(root.path): \(error)")
    exit(1)
}
log("notes folder: \(root.path), source: \(source.rawValue)")

func schema(for spec: ToolSpec) -> Value {
    var properties: [String: Value] = [:]
    for p in spec.params {
        properties[p.name] = .object(["type": .string(p.type), "description": .string(p.description)])
    }
    return .object([
        "type": .string("object"),
        "properties": .object(properties),
        "required": .array(spec.params.filter(\.required).map { .string($0.name) }),
    ])
}

func toolArgs(_ values: [String: Value]?) -> [String: ToolArg] {
    var out: [String: ToolArg] = [:]
    for (key, value) in values ?? [:] {
        if let i = value.intValue { out[key] = .int(i) }
        else if let s = value.stringValue { out[key] = .string(s) }
        else if let d = value.doubleValue { out[key] = ToolArg(double: d) }
    }
    return out
}

let server = Server(
    name: "anthology",
    version: MarginCore.version,
    title: "Anthology — notes from your AI tools",
    instructions: MarginTools.instructions(settings: MarginSettings.load()),
    capabilities: .init(tools: .init(listChanged: false))
)

await server.withMethodHandler(ListTools.self) { _ in
    .init(tools: tools.specs.map {
        Tool(name: $0.name, description: $0.description, inputSchema: schema(for: $0),
             annotations: .init(readOnlyHint: $0.readOnly, destructiveHint: $0.destructive))
    })
}

await server.withMethodHandler(CallTool.self) { params in
    let result = tools.call(params.name, toolArgs(params.arguments))
    if result.isError { log("\(params.name) failed: \(result.text)") }
    return .init(content: [.text(text: result.text, annotations: nil, _meta: nil)], isError: result.isError)
}

do {
    try await server.start(transport: StdioTransport())
    await server.waitUntilCompleted()
} catch {
    log("server error: \(error)")
    exit(1)
}
