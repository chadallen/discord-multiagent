#!/bin/zsh
# Saves a Discord bot token without echoing it, so it never appears on
# screen, in shell history or in an agent's chat.
# Usage: save-token.sh [state-dir]   (default ~/.claude/channels/discord-multiagent)
set -eu
dir=${1:-${DISCORD_STATE_DIR:-$HOME/.claude/channels/discord-multiagent}}
mkdir -p "$dir"
chmod 700 "$dir"
printf "Paste your bot token (input hidden), then press Enter: "
read -rs token
echo
[[ -n $token ]] || { echo "No token entered."; exit 1; }
umask 077
print -r -- "DISCORD_BOT_TOKEN=$token" > "$dir/.env"
chmod 600 "$dir/.env"
echo "Saved to $dir/.env"
