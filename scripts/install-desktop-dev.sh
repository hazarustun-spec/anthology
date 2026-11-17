#!/usr/bin/env bash
# Register anthology-mcp with Claude Desktop (chat + Cowork). Backs up the config first.
set -euo pipefail
BIN="$HOME/Library/Application Support/Anthology/bin/anthology-mcp"
CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
[ -x "$BIN" ] || { echo "Run scripts/install-dev.sh first"; exit 1; }
[ -f "$CFG" ] || echo '{}' > "$CFG"
cp "$CFG" "$CFG.anthology-backup-$(date +%Y%m%d%H%M%S)"
python3 -I - "$CFG" "$BIN" <<'PY'
import json, sys
path, binary = sys.argv[1], sys.argv[2]
with open(path) as f:
    cfg = json.load(f)
cfg.setdefault("mcpServers", {})["margin"] = {"command": binary, "args": ["--source", "cowork"]}
with open(path, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
PY
echo "Added margin to $CFG — restart Claude Desktop to load it."
