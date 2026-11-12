# Margin M1 — Core, MCP Server, First Mac Window · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Claude Code saves a note through the `margin-mcp` server, and it appears live in a basic Margin Mac window.

**Architecture:** One Swift package (`MarginKit`) holds `MarginCore` (file format, store, topic resolution, search) and the `margin-mcp` stdio executable. A thin SwiftUI Mac app (generated with XcodeGen) depends on `MarginCore` and watches the notes folder. Notes are Markdown files with front matter; history is JSONL.

**Tech Stack:** Swift 6 (Xcode 27.2), Swift Testing, `modelcontextprotocol/swift-sdk` 0.9.0, SwiftUI, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-12-margin-design.md`

## Milestone map (this plan = M1; later milestones get their own plans)

- **M1 (this plan):** core + MCP + Claude Code end-to-end + bare Mac window + Cowork spike.
- **M2:** Mac app product: design mockups for Hazar → Bear/Craft-level UI, live-styled Markdown editor, history sheet, menu bar extra, "Connect to Claude" onboarding, EN/TR localization.
- **M3:** iCloud container + iOS app (haptics) + cross-device conflict UI.
- **M4:** Launch: notarized DMG, public TestFlight, README with hero GIF, MIT license, App Store prep.

## Global Constraints

- Notes are plain Markdown files the user owns; no database (spec anti-goal 1).
- Never discard user text; stale writes are rejected, never merged silently (spec §6.4).
- Delete = move to `.trash/` (spec §6.3).
- Topic directory name is `<slug>-<4 hex>` and never changes after creation; title lives in `_topic.json` (spec §6.1–6.2).
- Note front matter keys exactly: `id`, `title`, `created`, `updated`, `revision` (spec §6.1).
- History line keys exactly: `rev`, `at`, `by`, `summary`, `project`; `by` ∈ `claude-code | cowork | app` (spec §6.1).
- Dates ISO-8601 UTC with `Z`.
- Platform floor: macOS 15, iOS 18. Bundle id: `com.marginnotes.Margin`.
- No dependency beyond the MCP Swift SDK in `MarginCore`/`margin-mcp`.
- Code, comments, commits in English.

## Review Focus

1. Turkish text everywhere (titles like "Kazanmak istediğim skiller", folder `Kariyer`): slugs transliterate (ç→c ğ→g ı→i İ→i ö→o ş→s ü→u), bodies round-trip byte-exact. → test in Task 2 and Task 3.
2. A note body containing `---` lines or YAML-looking text must not corrupt front matter. → Task 2.
3. Two topics whose folders share a basename (`~/a/Notes`, `~/b/Notes`): exact path wins; basename fallback only when no exact match exists, and only if exactly one topic matches. → Task 3.
4. Stale `update_note` (app saved in between) must fail with a clear message telling Claude to re-read. → Task 4 and Task 6.
5. Root folder missing on first run: created automatically, `list_topics` returns empty, not an error. → Task 3.

---

### Task 1: Package scaffold

**Files:**
- Create: `MarginKit/Package.swift`, `MarginKit/Sources/MarginCore/MarginCore.swift`, `MarginKit/Sources/margin-mcp/main.swift`, `MarginKit/Tests/MarginCoreTests/SmokeTests.swift`, `.gitignore`

**Interfaces:**
- Produces: library product `MarginCore`, executable product `margin-mcp`, test target `MarginCoreTests`. Swift tools 6.0, platforms `.macOS(.v15), .iOS(.v18)`. `margin-mcp` depends on `MCP` from `https://github.com/modelcontextprotocol/swift-sdk.git` `from: "0.9.0"`.

- [ ] Step 1: Write `SmokeTests.swift` with `@Test func coreLoads() { #expect(MarginCore.version == "0.1.0") }`.
- [ ] Step 2: Create package files; `public enum MarginCore { public static let version = "0.1.0" }`.
- [ ] Step 3: Run `cd MarginKit && swift test` → PASS; `swift build -c release --product margin-mcp` → succeeds.
- [ ] Step 4: Commit `chore: scaffold MarginKit package`.

### Task 2: Note file format

**Files:**
- Create: `MarginKit/Sources/MarginCore/NoteFile.swift`, `MarginKit/Tests/MarginCoreTests/NoteFileTests.swift`

**Interfaces:**
- Produces:
  - `public struct NoteMeta: Codable, Equatable, Sendable { id: String; title: String; created: Date; updated: Date; revision: Int }`
  - `public struct NoteFile: Equatable, Sendable { meta: NoteMeta; body: String }`
  - `NoteFile.parse(_ text: String) throws -> NoteFile` (throws `MarginError.malformedNote`)
  - `NoteFile.serialize() -> String`
  - `public enum MarginError: Error, Equatable, LocalizedError` — cases used across tasks: `malformedNote(String)`, `topicNotFound(String)`, `noteNotFound(String)`, `staleRevision(expected: Int, actual: Int)`, `ambiguousTopic([String])`, `conflict(String)`.
  - `public func newID() -> String` — 26-char ULID-style (timestamp + random, Crockford base32).

Front matter is written by us with fixed keys, so a minimal hand parser is enough: first line `---`, key lines `key: value` until the next line that is exactly `---`; title is written JSON-quoted (`title: "…"`) so any characters are safe; everything after the closing `---\n` is the body verbatim.

- [ ] Step 1: Tests:
  - `roundTripTurkish`: meta title `"Kazanmak istediğim skiller"`, body `"- SQL\n- Sistem tasarımı\n"` → `parse(serialize())` equals original.
  - `bodyWithDashes`: body `"a\n---\nb: c\n---\n"` round-trips exactly.
  - `titleWithQuotesAndColon`: title `He said: "hi"` round-trips.
  - `malformedThrows`: `parse("no front matter")` throws `.malformedNote`.
  - `idsAreUniqueAnd26Chars`: 1000 `newID()` values unique, all count 26.
- [ ] Step 2: Run `swift test --filter NoteFileTests` → FAIL (types missing).
- [ ] Step 3: Implement.
- [ ] Step 4: Run → PASS. Commit `feat(core): note file format`.

### Task 3: Store — root, topics, resolution

**Files:**
- Create: `MarginKit/Sources/MarginCore/MarginPaths.swift`, `MarginKit/Sources/MarginCore/Topic.swift`, `MarginKit/Sources/MarginCore/MarginStore.swift`, `MarginKit/Sources/MarginCore/Slug.swift`, `MarginKit/Tests/MarginCoreTests/TopicTests.swift`

**Interfaces:**
- Produces:
  - `public enum MarginPaths { static func defaultRoot(env: [String:String] = ProcessInfo.processInfo.environment) -> URL }` — order: `MARGIN_ROOT` env → `~/Library/Mobile Documents/iCloud~com~marginnotes~Margin/Documents` if it exists → `~/Library/Application Support/Margin/Notes`.
  - `public func slugify(_ s: String) -> String` — Turkish transliteration, lowercase, non-alphanumerics → `-`, collapsed, trimmed, max 40 chars, empty → `"topic"`.
  - `public struct Topic: Codable, Equatable, Sendable { id: String; title: String; sources: [String]; createdAt: Date; sortOrder: Int; var directoryName: String }` (directoryName not encoded; set on load).
  - `public final class MarginStore: @unchecked Sendable { init(root: URL) throws }` (creates root) with:
    - `listTopics() throws -> [Topic]` sorted by `sortOrder`, then title.
    - `createTopic(title: String, source: String?) throws -> Topic`
    - `resolveTopic(projectPath: String?, explicitTitle: String?) throws -> Topic` — explicitTitle (case-insensitive title match, else create) → exact source match → basename match against sources' last path components (exactly one → use it and append the new path to its `sources`; >1 → `.ambiguousTopic`) → create titled from prettified basename (`kariyer` → `Kariyer`, `career-notes` → `Career notes`). Nil/empty projectPath and no title → topic titled `Inbox`.
    - `renameTopic(id: String, title: String) throws -> Topic`
    - `addSource(topicID: String, source: String) throws`

- [ ] Step 1: Tests (each uses a fresh temp dir root):
  - `slugTurkish`: `slugify("Kazanmak İstediğim Şeyler")` == `"kazanmak-istedigim-seyler"`.
  - `missingRootCreated`: store at non-existent path → `listTopics()` == `[]`.
  - `resolveCreatesFromFolder`: `resolveTopic(projectPath: "/Users/x/Kariyer", explicitTitle: nil).title` == `"Kariyer"`; directory name matches `^kariyer-[0-9a-f]{4}$`.
  - `renameKeepsRouting`: create via path, rename to "Career", resolve same path again → same id, title "Career", directory name unchanged.
  - `basenameFallbackAddsSource`: topic from `/Users/x/Kariyer`, resolve `/sessions/abc/mnt/Kariyer` → same id, `sources` now contains both.
  - `ambiguousBasename`: topics from `/a/Notes` and `/b/Notes`, resolve `/c/Notes` → throws `.ambiguousTopic`; resolve `/a/Notes` → first topic.
  - `explicitTitleWins`: explicitTitle "Reading" with any path → topic titled "Reading" (created once, reused second time).
- [ ] Step 2: Run → FAIL. Step 3: Implement. Step 4: Run → PASS. Commit `feat(core): topics and resolution`.

### Task 4: Store — notes, revisions, history, search, trash

**Files:**
- Create: `MarginKit/Sources/MarginCore/MarginStore+Notes.swift`, `MarginKit/Sources/MarginCore/History.swift`, `MarginKit/Sources/MarginCore/FileIO.swift`, `MarginKit/Tests/MarginCoreTests/NoteStoreTests.swift`

**Interfaces:**
- Consumes: Task 2 types, Task 3 `MarginStore`, `Topic`.
- Produces:
  - `public enum ChangeSource: String, Codable, Sendable { case claudeCode = "claude-code", cowork, app }`
  - `public struct HistoryEntry: Codable, Equatable, Sendable { rev: Int; at: Date; by: ChangeSource; summary: String; project: String? }`
  - `public struct NoteRef: Equatable, Sendable { topic: Topic; meta: NoteMeta; fileURL: URL }`
  - On `MarginStore`:
    - `listNotes(topicID: String) throws -> [NoteRef]` sorted by `updated` desc.
    - `findNote(id: String) throws -> (NoteRef, NoteFile)` (`.noteNotFound`)
    - `findNote(topicID: String, title: String) throws -> (NoteRef, NoteFile)?` (case-insensitive)
    - `createNote(topicID: String, title: String, body: String, by: ChangeSource, summary: String, project: String?) throws -> NoteRef` — file name `slugify(title).md`, `-2`, `-3` suffix on collision; revision 1.
    - `appendToNote(id: String, text: String, by:, summary:, project:) throws -> NoteRef` — body + `"\n\n"` + text; revision +1.
    - `updateNote(id: String, baseRevision: Int, body: String, by:, summary:, project:) throws -> NoteRef` — throws `.staleRevision` if `baseRevision != current`.
    - `history(noteID: String) throws -> [HistoryEntry]`
    - `deleteNote(id: String) throws` — moves the `.md` to `<root>/.trash/<topicDir>/`.
    - `moveNote(id: String, toTopicID: String) throws -> NoteRef`
    - `search(_ query: String, limit: Int = 20) throws -> [(NoteRef, snippet: String)]` — case- and diacritic-insensitive substring over title + body; snippet ≈ 160 chars around first hit.
  - `FileIO.write(_ data: Data, to url: URL) throws` — `NSFileCoordinator` coordinated `.forReplacing` atomic write; before writing, if `NSFileVersion.unresolvedConflictVersionsOfItem(at:)` is non-empty, throw `.conflict(path)`. All store writes go through it.

- [ ] Step 1: Tests:
  - `createAndRead`: create note → `findNote(id:)` body equal, revision 1, history count 1 with `by == .claudeCode`.
  - `updateIncrementsAndLogs`: update with baseRevision 1 → revision 2, history last summary equals given.
  - `staleUpdateRejected`: update with baseRevision 1 twice → second throws `.staleRevision(expected: 1, actual: 2)`; file body equals first update's body.
  - `appendKeepsExisting`: append "- Go" to body "- SQL" → body `"- SQL\n\n- Go"`.
  - `filenameCollision`: two notes titled "Plan" → files `plan.md`, `plan-2.md`.
  - `deleteMovesToTrash`: note file gone from topic dir, exists under `.trash/`; `listNotes` excludes it.
  - `searchDiacritics`: body "Sistem tasarımı" found by query `"tasarimi"` and `"TASARIMI"`.
  - `listTopicsIgnoresTrash`: `.trash` and `.history` never appear as topics/notes.
- [ ] Step 2: FAIL. Step 3: Implement. Step 4: PASS. Commit `feat(core): notes, history, search`.

### Task 5: MCP tool layer (pure, testable)

**Files:**
- Create: `MarginKit/Sources/MarginCore/Tools/MarginTools.swift`, `MarginKit/Sources/MarginCore/Tools/Instructions.swift`, `MarginKit/Tests/MarginCoreTests/ToolsTests.swift`

**Interfaces:**
- Consumes: Task 3/4 store API.
- Produces: `public struct MarginTools { init(store: MarginStore, source: ChangeSource) ; func call(_ name: String, _ args: [String: ToolArg]) -> ToolResult }`, `public enum ToolArg { string(String), int(Int) }`, `public struct ToolResult { text: String; isError: Bool }`, `public static let toolSpecs: [ToolSpec]` (`name`, `description`, JSON-schema-as-dictionary of params), `public let serverInstructions: String`.
- Tools and params (exact names):
  - `list_topics()` → text listing `Topic title (id) — sources` then indented `• Note title (id, rev N, updated …)`.
  - `get_note(note_id?, topic?, title?)` → front-matter-free body preceded by a header line `# <title> · note_id=<id> · revision=<n>`.
  - `search_notes(query)`.
  - `save_note(content, summary, project_path?, topic?, note_title?)` → resolves topic; if `note_title` matches existing note → append; else create (title = `note_title` ?? first line of content stripped of `#`, max 60 chars). Returns `Saved to <topic> › <note> (note_id=…, revision=…)`.
  - `update_note(note_id, base_revision, content, summary)` → stale → `isError` with text `Note changed since you read it (now revision N). Call get_note again, merge, and retry.`
  - `rename_topic(topic_id, title)`, `move_note(note_id, topic_id)`, `delete_note(note_id)`.
  - `.ambiguousTopic` → `isError` listing candidate topics and asking Claude to pass `topic`.
  - `.conflict` → `isError` telling Claude the note has two versions and Hazar must resolve it in the Margin app.
- `serverInstructions` encodes spec §6.3 instructions and §6.4.1 consent rule; include: always pass `project_path` = current working/project folder; prefer updating an existing note in the topic (read with `get_note` then `update_note` with merged, tidy content) over creating duplicates; if no folder is known (e.g. Cowork) and topic unclear, ask the user which topic on first save; write in the user's language; offer to save notable things but only save after consent; explicit "save" = consent for that save and follow-up edits to that note in the same conversation.

- [ ] Step 1: Tests:
  - `saveCreatesThenAppends`: `save_note(content:"- SQL", summary:"x", project_path:"/u/Kariyer", note_title:"Skills")` twice → one note, body contains both lines, text contains `Kariyer › Skills`.
  - `updateStaleIsError`: get revision, update ok, update again with old revision → `isError` and text contains `Call get_note again`.
  - `ambiguousIsError`: two `/a/Notes`, `/b/Notes` topics, save with `/c/Notes` → `isError`, text contains both topic titles.
  - `missingRequiredArg`: `save_note` without `content` → `isError`, text names `content`.
  - `toolSpecsComplete`: names set == the 8 tool names above.
- [ ] Step 2: FAIL. Step 3: Implement. Step 4: PASS. Commit `feat(core): MCP tool layer`.

### Task 6: `margin-mcp` executable

**Files:**
- Modify: `MarginKit/Sources/margin-mcp/main.swift`
- Create: `scripts/mcp-smoke.sh`

**Interfaces:**
- Consumes: `MarginTools`, `toolSpecs`, `serverInstructions`, `MarginPaths.defaultRoot()`.
- Behavior: MCP `Server(name: "margin", version: MarginCore.version, instructions: serverInstructions, capabilities: tools)`, `StdioTransport`; `ListTools` maps `toolSpecs`; `CallTool` maps `Value` args to `ToolArg` and returns `.text`. CLI flag `--source cowork` (default `claude-code`) sets `ChangeSource`. Logs only to stderr.

- [ ] Step 1: Write `scripts/mcp-smoke.sh`: builds release binary, pipes `initialize`, `notifications/initialized`, `tools/list`, `tools/call save_note` JSON-RPC lines into it with `MARGIN_ROOT` = temp dir, asserts output contains `"save_note"` and `Saved to`, and that a `.md` file exists under the temp root. Exit 0 = pass.
- [ ] Step 2: Run → FAIL. Step 3: Implement main.swift. Step 4: Run → PASS. Commit `feat(mcp): stdio server`.

### Task 7: Claude Code end-to-end (real)

**Files:**
- Create: `scripts/install-dev.sh`, `docs/dev/claude-code-e2e.md` (result log)

- [ ] Step 1: `install-dev.sh`: builds release, copies binary to `~/Library/Application Support/Margin/bin/margin-mcp`, runs `claude mcp remove margin --scope user` (ignore failure) then `claude mcp add --scope user margin -- "<path>"`.
- [ ] Step 2: Run it; `claude mcp list` shows `margin` connected.
- [ ] Step 3: In a temp folder named `Kariyer`, run `claude -p "Kazanmak istediğim skiller: SQL ve sistem tasarımı. Bunu Margin'e kaydet." --allowedTools "mcp__margin__*"`; then a second run "Bir de Go dilini ekle Margin'deki skill listeme." Verify: one topic `Kariyer`, one note, body has all three skills (merged, not duplicated), history has ≥2 entries. Record outputs in `docs/dev/claude-code-e2e.md`.
- [ ] Step 4: If merge quality is poor, tune `serverInstructions` and repeat. Commit `test: Claude Code end-to-end verified`.

### Task 8: Bare Mac window with live reload

**Files:**
- Create: `App/project.yml`, `App/Margin/MarginApp.swift`, `App/Margin/LibraryModel.swift`, `App/Margin/Views/{TopicList,NoteList,NoteReader}.swift`, `App/Margin/Margin.entitlements`

**Interfaces:**
- Consumes: `MarginCore` via local package `../MarginKit`.
- Produces: `@Observable final class LibraryModel { topics: [Topic]; notes(for:) -> [NoteRef]; body(for:) -> String; reload() }` watching root with a `DispatchSource` file-system watcher on root + topic dirs (debounced 200 ms), falling back to 2 s polling. Three-column `NavigationSplitView`, read-only rendered Markdown (`AttributedString(markdown:)`), recently changed note gets a soft highlight for 2 s. App sandbox OFF for M1 (iCloud + sandbox handled in M3).

- [ ] Step 1: `xcodegen generate --spec App/project.yml` then `xcodebuild -project App/Margin.xcodeproj -scheme Margin -destination 'platform=macOS' build` → BUILD SUCCEEDED.
- [ ] Step 2: Launch app, run Task 7's Claude Code command with a new skill, screenshot showing the note update live. Save screenshot to `docs/dev/m1-demo.png`.
- [ ] Step 3: Commit `feat(app): bare Mac window with live reload`.

### Task 9: Cowork spike (needs Hazar for one step)

**Files:**
- Create: `scripts/install-desktop-dev.sh`, append findings to `docs/dev/cowork-spike.md`

- [ ] Step 1: Script backs up `~/Library/Application Support/Claude/claude_desktop_config.json` (if present) and adds `mcpServers.margin = {command: <binary>, args: ["--source","cowork"]}` preserving other keys (use `plutil`/`python3 -I` JSON edit).
- [ ] Step 2: Hazar restarts Claude Desktop, opens a Cowork folder, says "Bunu Margin'e kaydet: test notu". Record: does the tool appear, what `project_path` Claude passes, does the file land.
- [ ] Step 3: Write findings + chosen path (spec §9 risk 1) into `cowork-spike.md`. Commit `docs: Cowork spike findings`.
