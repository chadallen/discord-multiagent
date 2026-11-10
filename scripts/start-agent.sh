#!/usr/bin/env bash
# Starts a chat-only Claude Code session that receives Discord messages
# through the plugin. The only tools that exist are the plugin's, web search
# and claude.ai artifacts; anything else is refused without asking, and the
# plugin can't attach or download files. So a message can't get the agent to
# touch the computer or the owner's other accounts.
# Usage: start-agent.sh <agent-folder> [state-dir]
set -euo pipefail
folder=${1:?usage: start-agent.sh <agent-folder> [state-dir]}
if [[ -n ${2:-} ]]; then export DISCORD_STATE_DIR="$2"; fi
cd "$folder"

# --tools removes every other built-in tool. dontAsk refuses any tool not in
# --allowedTools, including other connectors, which stay loaded but unusable
# unless the user's own settings pre-approve them.
export DISCORD_ALLOW_FILES=0
exec claude --permission-mode dontAsk \
  --tools ToolSearch,WebSearch,Artifact \
  --allowedTools mcp__plugin_discord-multiagent_discord,WebSearch,Artifact \
  --dangerously-load-development-channels plugin:discord-multiagent@discord-multiagent
