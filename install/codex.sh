#!/usr/bin/env bash
# Install the Summation skill for OpenAI Codex CLI.
# The api skill is tool-agnostic (pure python3 + HTTPS); Codex discovers it
# from ~/.codex/skills. Workflow sub-skills are Claude-plugin packaging; under
# Codex the single skill plus live OpenAPI discovery covers the same surface.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/plugins/addison/skills/api"
DEST_DIR="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
DEST="$DEST_DIR/summation"

if [ ! -f "$SRC/SKILL.md" ]; then
  echo "error: cannot find skill source at $SRC" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"

if [ -L "$DEST" ]; then
  echo "replacing existing symlink: $DEST -> $(readlink "$DEST")"
  rm "$DEST"
elif [ -e "$DEST" ]; then
  echo "error: $DEST exists and is not a symlink — refusing to overwrite. Remove it and re-run." >&2
  exit 1
fi

ln -s "$SRC" "$DEST"
echo "installed: $DEST -> $SRC"
echo
echo "Credentials: run 'python3 $DEST/scripts/sum_api.py configure' (stores ~/.summation/skill-config, 0600)."
echo "Verify:      python3 $DEST/scripts/sum_api.py doctor"
echo
echo "When the hosted Summation MCP server ships, add to ~/.codex/config.toml:"
echo "  [mcp_servers.summation]"
echo "  url = \"https://mcp.summation.com/mcp\""
