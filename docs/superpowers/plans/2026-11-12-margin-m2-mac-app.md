# Margin M2 — Polished Mac App · Implementation Plan

> Executed inline (superpowers:executing-plans). Core logic is TDD; UI is verified with `--snapshot` renders.

**Goal:** Turn the bare M1 window into the product: Blocks theme, editable notes, history, menu bar, one-click Claude connection, EN/TR.
**Spec:** `docs/superpowers/specs/2026-11-12-margin-design.md` (§6.5, §7.1)

## Global Constraints
- Blocks palette from spec §7.1 (sage accent, card layout); appearance follows system by default.
- App writes go through `MarginStore` with `by: .app`; stale writes never overwrite Claude's text (spec §6.4).
- No shrill sounds. Mac haptic feedback (`NSHapticFeedbackManager`) on checkbox toggles only.
- English + Turkish via a String Catalog.

## Review Focus
1. User typing while Claude updates the same note → user's text kept, banner offers Claude's version.
2. Long notes (1000+ lines) → editor stays responsive (styling is incremental per edited paragraph).
3. Claude config files missing or malformed → Connect screen shows "Not connected" + a fix, never crashes or wipes the file.
4. Notes folder with 200+ notes → reload happens off the main thread.
5. Turkish casing in UI strings and search ("İ"/"ı").

## Tasks
1. **Core for the app** — `MarginStore.recentActivity(limit:) -> [ActivityItem]` (history entries across all notes, newest first, with topic and note titles); `createNote` from app; tests in `ActivityTests`.
2. **Theme + layout** — `Theme.swift` (dynamic colors), restyled sidebar/topic list/note list/reader, fresh-change wash, `--snapshot` dark + light.
3. **Editor** — `MarkdownTextView` (NSTextView): live styling (headings, bullets, `- [ ]` checkboxes clickable, bold/italic/code), autosave 600 ms debounced via `updateNote(baseRevision:)`; on `.staleRevision` keep the user's text and show the "Claude updated this note" banner with *Use Claude's version* / *Keep mine*.
4. **History + menu bar** — History popover per note (source icon, summary, time); `MenuBarExtra` with the latest 8 activity items, click opens the note.
5. **Connect to Claude** — Settings window: bundle `margin-mcp` in `Contents/Helpers`, install to `~/Library/Application Support/Margin/bin`, register with Claude Code (`claude mcp add` via the CLI found on PATH or inside Claude Desktop) and Claude Desktop (`claude_desktop_config.json`, backed up, other keys preserved). Status per client. JSON editing logic lives in `MarginCore/ClaudeConfig.swift` with tests.
6. **Localization + screenshots** — `Localizable.xcstrings` (en, tr); README-ready screenshots in `docs/screenshots/`.
