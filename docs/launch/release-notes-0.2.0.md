**Anthology is a notes app your AI tools write into.** Say "save this to Anthology" in Claude Code, Claude Desktop/Cowork, Cursor, VS Code, Gemini CLI or Codex, and it lands in a real Mac notes app — merged into the right note, with history and Undo.

### Install

```sh
curl -fsSL https://raw.githubusercontent.com/hazarustun-spec/anthology/main/install.sh | sh
```

or download `Anthology.dmg` below and drag it to Applications. Requires macOS 26 (Tahoe) or newer.
The app is signed with Developer ID and notarized by Apple; the installer refuses anything that isn't.

### What's in it

- **One-click connections** for Claude Code, Claude Desktop/Cowork, Cursor, VS Code, Gemini CLI and Codex (configs are backed up first; only Anthology's own entry is touched).
- **Claude Code plugin**: `/plugin marketplace add hazarustun-spec/anthology` → `/plugin install anthology@anthology`. Adds `/anthology:save` and `/anthology:recall`.
- **Chat shortcuts**: `//m …` files it into the right note without asking; `//m! …` saves it word for word and never reaches the model (zero tokens).
- **Living notes**: AI edits merge into existing notes; every change is in the note's history with Undo. Small icons in the margin show which tool wrote which lines.
- **Plain files**: notes are Markdown in iCloud Drive › Anthology. No account, no server.
- **Safe by default**: AI tools can't delete notes unless you allow it, writes are rate-limited, and note content is passed to models as data, not instructions.

iPhone app: coming soon (notes already sync via iCloud Drive).
