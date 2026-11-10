#!/usr/bin/env bash
# Starts a chat-only Claude Code session that receives Discord messages
# through the plugin. It loads only the plugin's Discord server, no other MCP
# servers or connectors, and no built-in tools except web search, and it
# can't attach or download files, so a message can't get it to touch the
# computer or the owner's accounts.
# Usage: start-agent.sh <agent-folder> [state-dir]
set -euo pipefail
folder=${1:?usage: start-agent.sh <agent-folder> [state-dir]}
if [[ -n ${2:-} ]]; then export DISCORD_STATE_DIR="$2"; fi
cd "$folder"

# --strict-mcp-config also drops plugins, so run the plugin's server on its
# own as "discord" from the installed copy.
cache="$HOME/.claude/plugins/cache/discord-multiagent/discord-multiagent"
root=$(ls -d "$cache"/*/ 2>/dev/null | sort -V | tail -1)
root=${root%/}
if [[ -z $root || ! -f $root/server.ts ]]; then
  echo "Plugin not installed. Run: claude plugin install discord-multiagent@discord-multiagent --scope project" >&2
  exit 1
fi
state=${DISCORD_STATE_DIR:-$HOME/.claude/channels/discord-multiagent}
mkdir -p "$state"
config="$state/chat-only.mcp.json"
python3 - "$root" "$config" <<'PY'
import json, sys
json.dump({"mcpServers": {"discord": {"command": "bun", "args": [
    "run", "--cwd", sys.argv[1], "--shell=bun", "--silent", "start"]}}},
    open(sys.argv[2], "w"), indent=2)
PY

# dontAsk denies anything not pre-approved; --tools removes every built-in
# tool except ToolSearch (to load the Discord tools) and WebSearch.
export DISCORD_ALLOW_FILES=0
exec claude --strict-mcp-config --mcp-config "$config" \
  --permission-mode dontAsk --tools ToolSearch,WebSearch \
  --allowedTools mcp__discord,WebSearch \
  --dangerously-load-development-channels server:discord
