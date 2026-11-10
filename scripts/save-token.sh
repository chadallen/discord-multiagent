#!/usr/bin/env bash
# Saves a Discord bot token to the agent's .env without printing it, so it
# never appears on screen, in shell history or in an agent's chat.
# --clipboard reads the token from the clipboard and then clears it, so a
# setup agent can run this itself after the person clicks Copy. Without it,
# the script reads hidden input typed in a terminal.
# Usage: save-token.sh [--clipboard] [state-dir]
#   (default state dir ~/.claude/channels/discord-multiagent)
set -euo pipefail
from_clipboard=0
if [[ ${1:-} == --clipboard ]]; then from_clipboard=1; shift; fi
dir=${1:-${DISCORD_STATE_DIR:-$HOME/.claude/channels/discord-multiagent}}

read_clipboard() {
  if command -v pbpaste >/dev/null; then pbpaste
  elif command -v wl-paste >/dev/null; then wl-paste -n
  elif command -v xclip >/dev/null; then xclip -o -selection clipboard
  elif command -v xsel >/dev/null; then xsel -bo
  elif command -v powershell.exe >/dev/null; then powershell.exe -NoProfile -Command Get-Clipboard
  else return 1
  fi
}

clear_clipboard() {
  if command -v pbcopy >/dev/null; then printf '' | pbcopy
  elif command -v wl-copy >/dev/null; then wl-copy --clear
  elif command -v xclip >/dev/null; then printf '' | xclip -selection clipboard
  elif command -v xsel >/dev/null; then xsel -bc
  elif command -v clip.exe >/dev/null; then printf '' | clip.exe
  fi 2>/dev/null || true
}

if (( from_clipboard )); then
  token=$(read_clipboard) || { echo "No clipboard tool found. Run without --clipboard to type the token instead."; exit 1; }
else
  printf "Paste your bot token (input hidden), then press Enter: "
  read -rs token
  echo
fi
token=$(printf '%s' "$token" | tr -d '[:space:]')

# Bot tokens are three base64url parts joined by dots. Checking the shape
# catches a stale clipboard or a mis-paste without showing what was there.
if [[ ! $token =~ ^[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{20,}$ ]]; then
  echo "That doesn't look like a Discord bot token (${#token} characters). Nothing saved."
  echo "On the bot's page, click Copy under the token and try again."
  exit 1
fi

mkdir -p "$dir"
chmod 700 "$dir"
umask 077
printf 'DISCORD_BOT_TOKEN=%s\n' "$token" > "$dir/.env"
chmod 600 "$dir/.env"
if (( from_clipboard )); then clear_clipboard; fi
echo "Saved to $dir/.env"
