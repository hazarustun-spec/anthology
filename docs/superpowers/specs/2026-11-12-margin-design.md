# Margin — Notes for Claude · Design

Date: 2026-11-12 · Owner: Hazar · Status: draft, awaiting approval

## 1. Intent

Hazar uses Claude Code and Claude Cowork (Claude Desktop) heavily. During
conversations he often tells Claude "note this down" — e.g. in a Cowork
working folder about his career he listed skills he wants to gain. Today
those notes end up scattered in files Claude writes inside each project, or
Hazar copies them by hand into his own notebooks.

Margin is a native macOS + iOS notes app that Claude writes into. When Hazar
says "save this to the app" (in either Claude Code or Cowork), Claude files the
note under the right topic, keeps it up to date over time, and Hazar can read
and edit it later on his Mac or iPhone without opening Claude. Claude can also
read the notes back in later conversations, so the notes become Claude's
long-term memory across projects.

Primary goal: an open-source GitHub project that earns stars. That means:
polished visuals (competitor-level, Bear/Craft feel), a 60-second setup, and a
README with a GIF that shows the "say it in Claude → it appears on your phone"
moment.

## 2. Goals

1. Claude (Code and Cowork/Desktop) can save, update, list, search and read
   notes through an MCP server.
2. Notes are organized as **Topic → Notes**. A topic corresponds to a project
   folder (e.g. Cowork folder "Kariyer" → topic "Kariyer").
3. Each note is a **living document**: Claude merges new information into it
   (adds a skill to the skill list) instead of appending duplicates. Every
   change is recorded in a per-note history (when, from where, one-line
   summary).
4. Native SwiftUI app for macOS and iOS (one codebase), full editing, synced via
   iCloud.
5. Mac menu bar extra: recent activity ("Claude just added to Kariyer"), quick
   peek.
6. UI in English and Turkish (follows system language; English default).
7. Claude saves when told, and also *offers* ("Want me to add this to your
   Margin notes?") when something looks note-worthy. It never saves silently.

## 3. Non-goals (v1)

- No server, account, or backend of our own. No web app. No Android.
- No AI inside the app itself (the app does not call any model API). Claude is
  the intelligence; the app is the home for the notes.
- No real-time collaborative editing with other people. No sharing.
- No attachments/images in notes (text + Markdown only).
- No support for claude.ai web chat (it cannot reach a local MCP server).

## 4. Anti-goals (would be a failure even if it "works")

- Notes trapped in a proprietary format. Notes must stay plain Markdown files
  the user owns and can open anywhere.
- Claude overwriting edits Hazar made in the app.
- Claude saving things without being asked or without offering first.
- A setup that requires editing JSON by hand.
- A look that feels like a developer demo instead of a real product.

## 5. Decisions made with Hazar

| Topic | Decision |
|---|---|
| Name | **Margin** — subtitle "Notes for Claude". "Claude" not in the main name (trademark). |
| Phone | Native iPhone app, same codebase, iCloud sync. Hazar has a paid Apple Developer account. |
| Topics | Created from the project folder. Hazar can rename a topic; Claude keeps writing to it from the same folder after the rename. |
| Structure | Topic contains multiple notes. Claude picks the right note or creates a new one. |
| Updates | Living document + change history. |
| Editing | Full editing in the app (Mac and iPhone). |
| Trigger | On request, plus Claude may offer. Never silent. |
| Read-back | Yes, Claude can search and read notes. |
| Style | Bear / Craft: warm, typography-first, soft motion, haptics on iOS. No shrill sounds. |
| Language | English + Turkish UI. |
| Mac access | Main window + menu bar extra. |

## 6. Technical decisions (Claude's calls, with reasons)

### 6.1 Storage: plain Markdown in the app's iCloud Drive container
- Location: the app's iCloud ubiquity container
  (`~/Library/Mobile Documents/iCloud~<bundle-id>/Documents/`), visible to the
  user in Finder/Files as a "Margin" folder.
- Reason: no backend, zero cost, Apple handles sync to iPhone, files are owned
  by the user (anti-goal 1), and "your notes are just Markdown" is a strong
  open-source selling point. Rejected: SwiftData + CloudKit (opaque DB, MCP
  server can't write it safely from outside the app).

Layout:
```
Margin/
  kariyer-3f9a/                 # topic directory: slug + short id, never renamed
    _topic.json                 # {id, title, sources:[...], createdAt, sortOrder}
    skills-to-gain.md           # a note
    interview-prep.md
    .history/
      skills-to-gain.jsonl      # one line per change
```

Note file = Markdown with YAML front matter:
```yaml
---
id: 01JC...                 # ULID, stable
title: Skills to gain
created: 2026-11-12T10:04:00Z
updated: 2026-11-12T11:30:00Z
revision: 7                 # increments on every write
---
...markdown body...
```

History line:
`{"rev":7,"at":"…","by":"claude-code|cowork|app","summary":"Added 'SQL' to the skill list","project":"/Users/…/Kariyer"}`

### 6.2 Topic identity (rename-safe)
- `_topic.json.sources` holds the project identifiers that map to the topic:
  the absolute project path for Claude Code, and the folder name/path Cowork
  reports. Title is separate and freely editable.
- Lookup order when Claude saves: exact source match → same folder basename
  match → create a new topic titled from the folder name (prettified,
  e.g. `kariyer` → "Kariyer").
- Hazar can also attach additional folders to a topic, or merge two topics,
  in the app (v1: attach folder; merge is v1.1).
- Claude may pass an explicit `topic` to override ("save this to my Reading
  topic").

### 6.3 Claude integration: MCP server written in Swift, bundled in the app
- A small stdio MCP server binary (`margin-mcp`) built with the official
  Swift MCP SDK, shipped inside the Mac app bundle. Reason: one language, one
  shared `MarginCore` package for file format logic, no Node/Python
  dependency for users.
- Setup is one click in the app (Settings → "Connect to Claude"):
  - Claude Code: runs `claude mcp add --scope user margin <path>` (or writes
    `~/.claude.json` equivalently if the CLI is absent).
  - Claude Desktop / Cowork: adds the server to Claude Desktop's MCP config
    (and/or ships a `.mcpb` desktop extension). Must be verified in the
    first spike (see §9 risk 1).
  - Shows a green "Connected" check per client.
- Also documented manual install for people who build from source.

Tools exposed:
| Tool | Purpose |
|---|---|
| `list_topics` | Topics with titles, note titles, last updated. |
| `get_note(topic?, note)` | Full Markdown + current `revision`. |
| `search_notes(query)` | Full-text search across all notes. |
| `save_note(project_path, topic?, note_title?, content, summary)` | Create a note, or append to a note when Claude has not read it. |
| `update_note(note_id, base_revision, content, summary)` | Replace the body of a living note after Claude merged new info. Rejected if `base_revision` is stale → Claude re-reads and retries. |
| `rename_topic`, `move_note`, `delete_note` | Housekeeping when Hazar asks Claude. Delete moves to a `.trash/` folder. |

Server instructions (MCP `instructions` field) tell Claude: when the user
says "save to the app / Margin / my notes", use these tools; prefer updating
an existing note in the topic over creating a new one; read before update;
keep notes tidy and structured; offer to save notable things but never save
without consent; write in the language the user is speaking.

### 6.4 Concurrency / never overwrite the user
- Optimistic concurrency via `revision` (above). The app increments
  `revision` on its own saves too.
- File writes use `NSFileCoordinator` (atomic replace) in both app and MCP
  server; the app uses `NSFilePresenter`/`NSMetadataQuery` to live-reload when
  a file changes, with a subtle highlight animation on the changed section.
- If Hazar is actively editing a note when Claude's update lands, the app
  keeps his text, and shows a banner "Claude updated this note — view changes"
  (v1: show both versions side by side and let him pick).

#- **Cross-device conflicts (Claude's call).** `revision` only protects
  writers on the same Mac. iCloud does not merge edits made on two devices; it
  keeps one version and stores the other as an `NSFileVersion` conflict. Both
  apps watch for unresolved conflict versions. Rule: nothing is ever
  discarded automatically. The app shows a "Two versions of this note" banner
  with both versions side by side; Hazar picks one or keeps both (the other
  becomes "<title> (conflict copy)"). The MCP server, on detecting a
  conflict, reports it to Claude instead of writing.

### 6.4.1 Consent rule (Claude's call)
- An explicit request ("save this", "add it to Margin") is consent for that
  save and for follow-up edits to the same note that Hazar asks for in the
  same conversation. No extra confirmation prompt.
- When Claude *offers* on its own, it saves only after a "yes", and that yes
  covers only that one save.

### 6.5 Apps
- One Xcode project, SwiftUI, multiplatform target (macOS 15+, iOS 18+ —
  builder may raise to current OS if it simplifies; must run on Hazar's
  current devices).
- Shared Swift package `MarginCore`: models, Markdown file format, history,
  topic resolution, search. Used by Mac app, iOS app, and `margin-mcp`.
- Mac: three-column `NavigationSplitView` (Topics → Notes → Editor), menu bar
  extra, global search (⌘K style), "Connect to Claude" onboarding.
- iOS: same hierarchy with stack navigation, haptics on save/check/delete,
  pull to refresh not needed (live iCloud updates).
- Editor: Markdown with live styling (headings, lists, checkboxes tappable,
  bold/italic, code). Not a split preview. A per-note "History" sheet shows the
  change log with source badges (Claude Code / Cowork / You).
- Visual direction: warm paper-like light theme and deep warm dark theme,
  serif or high-quality humanist typography for note bodies, generous
  spacing, soft spring animations. A small badge shows "via Claude Code" /
  "via Cowork" on recently changed notes.
- Localization: String Catalog, English + Turkish.

### 6.6 Distribution & open source
- MIT license, public GitHub repo, README with hero GIF, 60-second setup,
  architecture diagram, FAQ (privacy: nothing leaves your iCloud).
- Mac: signed + notarized DMG on GitHub Releases. iPhone: **public TestFlight
  link at launch** so anyone from GitHub can install it (Hazar's call); App
  Store submission is the next milestone after launch.

## 7. Example flow

1. In Cowork folder `Kariyer`, Hazar: "SQL ve sistem tasarımını da kazanmak
   istediğim skillere ekle, app'e kaydet."
2. Claude calls `list_topics` → finds topic for `Kariyer` with note "Skills
   to gain" → `get_note` → merges the two skills into the list →
   `update_note(base_revision: 6, summary: "Added SQL, system design")`.
3. iCloud syncs. Mac menu bar shows "Kariyer · Skills to gain updated".
   Hazar's iPhone shows the updated list with the two new items highlighted.
4. A week later in Claude Code: "Skill listeme göre bu haftaya plan yap" →
   Claude calls `search_notes("skill")` and reads the note.

## 7.1 Visual direction (Hazar's pick, 2026-11-12): "Blocks" (option C)
- Craft-like: airy light canvas (#F4F5F2), content on white rounded cards with hairline borders,
  **sage green accent (#5E7D5A)**, clean sans typography (SF), topic rows with icons.
- Checklists render as real checkboxes; sections can sit in soft tinted blocks.
- Dark mode is the same system on a deep green-gray canvas (#1B1D1A) with lighter sage (#8FB08A).
- Fresh changes from Claude: soft sage wash on the note card, highlighted new lines, and a source
  badge ("Cowork · Added SQL and system design").
- (Briefly built as "Ink"/option B by mistake; Hazar corrected to C.)

## 7.2 Liquid Glass "Ambient" (Hazar's pick, 2026-11-16)
- A slowly drifting sage / amber / sky mesh gradient backs every screen (deep green-navy in dark mode);
  falls back to a flat canvas with Reduce Transparency and stops moving with Reduce Motion.
- Sidebar, note cards, topic tiles, the editor sheet, palettes and banners are Liquid Glass panels
  floating on it (with a light fill for legibility). Toolbars use system glass.

## 7.3 Professional / simple (Hazar, 2026-11-16) — supersedes 7.2
- Readability first: calm solid canvas, plain cards with hairline borders, the editor is a clean
  page. No animated backdrop, no glass content panels, no glare.
- System Liquid Glass stays only where Apple puts it (toolbar, sidebar, search palette, sheets).
- Mac "Show the desktop behind the window" remains as an opt-in setting (off by default).

## 8. Left to the builder

Exact visual design (within §6.5 direction; mockups shown to Hazar before
polishing), Markdown editor implementation, search implementation, error
copy, icon design drafts (Hazar picks), test strategy, project structure.

## 9. Risks to verify first (spike before full build)

1. **Cowork + local MCP.** Confirm Claude Desktop's Cowork mode can call a
   local stdio MCP server, and what "project folder" path it can report. If
   it cannot connect, fallback: Cowork writes via a desktop extension (`.mcpb`)
   or the app watches a drop folder Cowork can write to. If Cowork connects
   but cannot report its folder, **Claude asks "which topic?"** on the first
   save in that conversation (or guesses from context and confirms) — this
   does not block launch (Hazar's call). UI work may start in parallel with
   the spike.
2. **iCloud container access from the MCP binary.** The non-sandboxed helper
   must read/write the app's ubiquity container path reliably, and files it
   writes must sync to iOS. Verify on Hazar's devices.
3. **Living-document merges quality.** Depends on the server instructions;
   test with real prompts (career-skills scenario) and tune.
