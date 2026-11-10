#!/bin/zsh
# Starts a Claude Code session that receives Discord messages through the
# plugin. Chat-only by default: the only tools the agent can use are the
# plugin's own, so a message can't get it to run commands or edit files.
# Usage: start-agent.sh [--full] <agent-folder> [state-dir]
#   --full  auto mode, so the agent can also work on this computer
set -eu
full=false
if [[ ${1:-} == --full ]]; then full=true; shift; fi
folder=${1:?usage: start-agent.sh [--full] <agent-folder> [state-dir]}
[[ -n ${2:-} ]] && export DISCORD_STATE_DIR="$2"
cd "$folder"
channel=plugin:discord-multiagent@discord-multiagent
if $full; then
  exec claude --permission-mode auto --dangerously-load-development-channels $channel
fi
# dontAsk denies anything not pre-approved, including the user's own
# allow rules for shell commands, so built-in tools are removed outright too.
exec claude --permission-mode dontAsk --tools ToolSearch \
  --allowedTools mcp__plugin_discord-multiagent_discord \
  --dangerously-load-development-channels $channel
