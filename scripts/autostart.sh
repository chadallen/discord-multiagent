#!/usr/bin/env bash
# Makes a Discord agent start by itself when its owner logs in to macOS.
# It installs a launchd login item that runs start-agent.sh in tmux with
# DISCORD_AUTO_CONFIRM=1, which answers the development-channels warning.
# Usage: autostart.sh install <agent-folder> [state-dir]
#        autostart.sh remove <agent-folder>
set -euo pipefail
action=${1:?usage: autostart.sh install|remove <agent-folder> [state-dir]}
folder=${2:?usage: autostart.sh install|remove <agent-folder> [state-dir]}
state=${3:-$HOME/.claude/channels/discord-multiagent}
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [[ $(uname) != Darwin ]]; then
  echo "Login items are macOS only. On Linux, run start.sh from a systemd user service or your desktop's autostart instead."
  exit 1
fi

folder=$(cd "$folder" && pwd -P)
name=$(basename "$folder" | sed 's/[^A-Za-z0-9_-]/-/g')
label="com.discord-multiagent.$name"
plist="$HOME/Library/LaunchAgents/$label.plist"
domain="gui/$(id -u)"

case $action in
  install)
    command -v tmux >/dev/null || { echo "Install tmux first (brew install tmux): without it the agent would need an open terminal."; exit 1; }
    mkdir -p "$HOME/Library/LaunchAgents" "$state"
    # launchd starts jobs with a minimal PATH, so record the one that finds
    # claude, bun, tmux and python3 now.
    python3 - "$plist" "$label" "$script_dir/start-agent.sh" "$folder" "$state" "$PATH" <<'EOF'
import plistlib, sys
plist, label, script, folder, state, path = sys.argv[1:]
with open(plist, "wb") as f:
    plistlib.dump({
        "Label": label,
        "ProgramArguments": ["/bin/bash", script, folder, state],
        "EnvironmentVariables": {"PATH": path, "DISCORD_AUTO_CONFIRM": "1", "LANG": "en_US.UTF-8"},
        "RunAtLoad": True,
        "StandardOutPath": f"{state}/autostart.log",
        "StandardErrorPath": f"{state}/autostart.log",
    }, f)
EOF
    launchctl bootout "$domain/$label" 2>/dev/null || true
    launchctl bootstrap "$domain" "$plist"
    echo "Installed $plist. The agent in $folder now starts when you log in."
    echo "Log: $state/autostart.log"
    ;;
  remove)
    launchctl bootout "$domain/$label" 2>/dev/null || true
    rm -f "$plist"
    echo "Removed the login item for $folder. A running agent keeps running."
    ;;
  *)
    echo "usage: autostart.sh install|remove <agent-folder> [state-dir]"
    exit 1
    ;;
esac
