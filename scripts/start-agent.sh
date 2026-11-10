#!/bin/zsh
# Starts a Claude Code session that receives Discord messages through the
# plugin. Auto mode, because the session takes input from a shared channel.
# Usage: start-agent.sh <agent-folder> [state-dir]
set -eu
folder=${1:?usage: start-agent.sh <agent-folder> [state-dir]}
[[ -n ${2:-} ]] && export DISCORD_STATE_DIR="$2"
cd "$folder"
exec claude --permission-mode auto \
  --dangerously-load-development-channels plugin:discord-multiagent@discord-multiagent
