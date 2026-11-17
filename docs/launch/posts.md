# Launch posts

Drafts for launch day. Post the GitHub release first; every post links to the repo.
Repo: https://github.com/hazarustun-spec/anthology

---

## Hacker News — Show HN

**Title:** Show HN: Anthology – a Mac notes app that Claude, Cursor and Codex write into

**Body:**

I talk to AI tools all day, and the things worth keeping (decisions, lists, "skills I want to learn") end up buried in chat history or in random files inside each project.

Anthology is a native Mac notes app with a local MCP server inside it. One click connects Claude Code, Claude Desktop, Cursor, VS Code, Gemini CLI or Codex. Then you say "save this to Anthology" and it lands in a real note — and the AI merges new information into the existing note instead of appending another snippet.

A few details I cared about:

- Notes are plain Markdown files in iCloud Drive. No account, no backend.
- Each project folder becomes a topic, so notes from different repos don't mix.
- Every AI edit is versioned with Undo, updates are compare-and-set so the AI never overwrites what you just typed, and deletion by AI is off by default.
- A small icon in the margin shows which tool wrote which lines.
- In Claude Code, `//m! call Ali tomorrow` is captured by a hook and never reaches the model.

Written in Swift/SwiftUI, MIT licensed. macOS 26+. Install: `curl -fsSL https://raw.githubusercontent.com/hazarustun-spec/anthology/main/install.sh | sh`

Happy to answer questions about the MCP side or the editor.

---

## Reddit — r/ClaudeAI, r/macapps

**Title:** I made a free, open-source Mac notes app that Claude Code / Claude Desktop write into

**Body:**

Anthology is a native notes app with a built-in MCP server. Connect it to Claude (or Cursor, VS Code, Gemini CLI, Codex) with one click, then say "save this to Anthology" in any chat.

- The AI updates the right note instead of creating duplicates (adds SQL to your existing skill list)
- Each project folder = a topic
- Plain Markdown in iCloud Drive, no account, no server
- History + Undo for every AI edit; AI can't delete unless you allow it
- `//m` shortcut to save without asking, `//m!` to save word-for-word with zero tokens

MIT, macOS 26+. GitHub: https://github.com/hazarustun-spec/anthology

Feedback welcome — especially which other tools you'd want it to work with.

---

## X / Twitter (thread)

1/ I built Anthology: a Mac notes app that your AI tools write into.

Say "save this to Anthology" in Claude Code, Claude Desktop, Cursor, Codex or Gemini CLI → it lands in a real note. Open source.

[screenshot: live-update-tr.png]

2/ The AI doesn't just append. It finds the right note and merges — your skill list gets one more line, not another copy.

Every change has history + Undo. Small margin icons show who wrote what.

[screenshot: line-authors.jpg]

3/ Your notes are plain Markdown in iCloud Drive. No account, no server.

One-line install (macOS 26+):
curl -fsSL https://raw.githubusercontent.com/hazarustun-spec/anthology/main/install.sh | sh

github.com/hazarustun-spec/anthology

---

## LinkedIn / X (Türkçe)

Bugün workshop'ta Anthology'yi tanıttım: yapay zekâ araçlarının içine yazdığı açık kaynak bir Mac not uygulaması.

Claude Code, Claude Desktop, Cursor, Codex ya da Gemini CLI'da "bunu Anthology'ye kaydet" diyorsun; not doğru yere, düzenli şekilde düşüyor. Notlar iCloud Drive'da düz Markdown dosyaları; hesap yok, sunucu yok. Yapay zekânın her değişikliği geri alınabilir.

Tek satırla kurulum (macOS 26+):
curl -fsSL https://raw.githubusercontent.com/hazarustun-spec/anthology/main/install.sh | sh

GitHub: https://github.com/hazarustun-spec/anthology — yıldız bırakırsanız çok sevinirim ⭐
