# Cowork / Claude Desktop spike (spec §9 risk 1)

## 2026-11-12 — first attempt
- Claude Code (desktop Code tab): works. `claude mcp add --scope user margin …` is picked up by new
  Code sessions. A real save landed (topic "Web sitesi"). Claude passed `topic` but no `project_path`
  despite the instructions → fixed by defaulting to the server's working directory (Claude Code
  starts MCP servers in the project folder).
- Cowork: not yet exercised. `margin` was added to `claude_desktop_config.json`, but Claude Desktop
  had been running since 00:01 and was never restarted, so no `mcp-server-margin.log` exists and no
  `by: cowork` write reached the notes folder. Retest after a full ⌘Q restart.
- `claude_desktop_config.json` has `coworkUserFilesPath = ~/Documents/Claude` — likely root of Cowork
  folders; check what `project_path` Cowork reports on retest.
- Install gotcha: overwriting the installed binary in place got it SIGKILLed (exit 137, stale
  code-signature cache). Install scripts now `rm` before `cp`.

## 2026-11-12 — why the Desktop entry vanished
- `claude_desktop_config.json` was rewritten by the running Claude Desktop at 05:20 and the
  `mcpServers.margin` entry was gone. Claude Desktop keeps the config in memory and writes it back,
  so edits made while it runs are lost. The Connect button therefore quits Claude, writes the
  config, and reopens Claude.

## 2026-11-14 — iCloud end-to-end verified (spec §9 risk 2)
- margin-mcp (no entitlements) writes into `~/Library/Mobile Documents/iCloud~<bundle>/Documents`;
  files upload (`ubiquitousItemIsUploaded == true`) and appeared on Hazar's iPhone 14 Pro Max
  within seconds. The Mac app records the folder in `~/Library/Application Support/Margin/notes-root`.
- Latency: hook 0.5 s; MCP tool calls 0.2–0.5 s.
