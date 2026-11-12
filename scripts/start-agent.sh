#!/usr/bin/env bash
# Starts a chat-only Claude Code session that receives Discord messages
# through the plugin. The only tools that exist are the plugin's, web search,
# claude.ai artifacts, and file tools limited to the session's own scratch
# folder, where the Artifact tool keeps its working copies, and the agent's
# memory folder. Anything else is
# refused without asking, and the plugin can't attach or download files. So
# a message can't get the agent to touch the computer or the owner's other
# accounts.
# Usage: start-agent.sh <agent-folder> [state-dir]
set -euo pipefail
folder=${1:?usage: start-agent.sh <agent-folder> [state-dir]}
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [[ -n ${2:-} ]]; then export DISCORD_STATE_DIR="$2"; fi
state=${DISCORD_STATE_DIR:-$HOME/.claude/channels/discord-multiagent}

mkdir -p "$folder"
folder=$(cd "$folder" && pwd -P)
use_tmux=
if [[ -z ${TMUX:-} && -z ${DISCORD_NO_TMUX:-} ]] && command -v tmux >/dev/null; then use_tmux=1; fi
name=$(basename "$folder" | sed 's/[^A-Za-z0-9_-]/-/g')

# Run the agent inside tmux, when it's installed, so it keeps running with no
# terminal open and its owner can reattach to watch or answer it. Running this
# again reattaches. DISCORD_NO_TMUX=1 runs it in this terminal instead.
if [[ -n $use_tmux ]] && tmux has-session -t "=$name" 2>/dev/null; then
  if [[ -t 0 ]]; then exec tmux attach -t "=$name"; fi
  echo "Already running in tmux session $name. Attach with: tmux attach -t $name"
  exit 0
fi

# Closing a terminal tab can leave its session running and connected. A
# second session on the same bot would answer every message twice, so refuse
# while the session recorded here is alive. The check on the command guards
# against a reused process ID.
lock=$state/agent.pid
if [[ -f $lock ]]; then
  pid=$(cat "$lock")
  if [[ $pid =~ ^[0-9]+$ ]] && ps -p "$pid" -o command= 2>/dev/null | grep -q claude; then
    echo "This agent is already running as process $pid, so it would answer every message twice."
    echo "Close that session (/exit), or stop it with: kill $pid"
    exit 1
  fi
fi

# Offer a newer plugin version before starting. The check only reads GitHub:
# updating rewrites this script, which bash reads as it runs, so the update
# and the restart of this script happen inside this one if-block, which bash
# reads in full before running. DISCORD_UPDATE=yes updates without asking,
# DISCORD_UPDATE=no skips the check; without a terminal it never asks.
market=$HOME/.claude/plugins/marketplaces/discord-multiagent
if [[ -z ${DISCORD_UPDATE_CHECKED:-} && ${DISCORD_UPDATE:-} != no && -d $market/.git ]]; then
  export DISCORD_UPDATE_CHECKED=1
  have=$(python3 -c '
import json, os, sys
try:
    with open(os.path.expanduser("~/.claude/plugins/installed_plugins.json")) as f:
        entries = json.load(f).get("plugins", {}).get("discord-multiagent@discord-multiagent", [])
except (OSError, ValueError):
    entries = []
print(next((e.get("version", "") for e in entries if e.get("projectPath") == sys.argv[1]), ""))
' "$folder")
  latest=$( { git -C "$market" fetch -q origin 2>/dev/null &&
    git -C "$market" show FETCH_HEAD:plugins/discord-multiagent/.claude-plugin/plugin.json 2>/dev/null |
    python3 -c 'import json, sys; print(json.load(sys.stdin)["version"])' 2>/dev/null; } || true)
  if [[ -n $have && -n $latest && $have != "$latest" ]]; then
    answer=${DISCORD_UPDATE:-}
    if [[ -z $answer && -t 0 ]]; then
      read -r -t 60 -p "A newer Discord plugin is available ($latest; this agent has $have). Update now? [Y/n] " reply || reply=n
      if [[ -z $reply || $reply == [Yy]* ]]; then answer=yes; fi
    fi
    if [[ $answer == yes ]]; then
      echo "Updating to $latest..."
      claude plugin marketplace update discord-multiagent >/dev/null &&
        (cd "$folder" && claude plugin update discord-multiagent@discord-multiagent --scope project >/dev/null) &&
        exec bash "$market/scripts/start-agent.sh" "$folder"
      echo "The update failed. Start again to retry, or with DISCORD_UPDATE=no to skip it."
      exit 1
    fi
  fi
fi

if [[ -n $use_tmux ]]; then
  inner=$(printf '%q ' env "DISCORD_STATE_DIR=$state" DISCORD_UPDATE_CHECKED=1 \
    ${DISCORD_TURN_SECONDS:+"DISCORD_TURN_SECONDS=$DISCORD_TURN_SECONDS"} \
    bash "$script_dir/start-agent.sh" "$folder")
  tmux new-session -d -s "$name" "$inner"
  if [[ -t 0 ]]; then exec tmux attach -t "=$name"; fi
  echo "Started in tmux session $name. Attach with: tmux attach -t $name"
  exit 0
fi

cd "$folder"

# A project-scope install belongs to one folder, and enabling the plugin in a
# folder's settings without installing it there leaves the session deaf to
# Discord with no error. So install it for this folder if it isn't already.
plugin=discord-multiagent@discord-multiagent
installed=$(python3 - "$plugin" "$(pwd -P)" "$PWD" <<'EOF'
import json, os, sys
plugin, *paths = sys.argv[1:]
try:
    with open(os.path.expanduser("~/.claude/plugins/installed_plugins.json")) as f:
        entries = json.load(f).get("plugins", {}).get(plugin, [])
except (OSError, ValueError):
    entries = []
print(any(e.get("scope") == "user" or e.get("projectPath") in paths for e in entries))
EOF
)
if [[ $installed != True ]]; then
  echo "Installing $plugin for $(pwd -P)..."
  claude plugin install "$plugin" --scope project
fi

# Claude Code keeps each session's scratch folder at
# <tmp>/claude-<uid>/<project slug>/<session>/scratchpad, the slug being this
# folder's path with every other character turned into "-". Scoping to this
# slug keeps the agent out of other projects' scratch folders, which can hold
# transcripts.
slug=$(pwd -P | sed 's#[^A-Za-z0-9]#-#g')
scratch_rules=()
for tmp in /private/tmp /tmp; do
  pattern="/$tmp/claude-$(id -u)/$slug/*/scratchpad/**"
  # Edit rules cover every file-writing tool, Write included.
  scratch_rules+=("Read($pattern)" "Edit($pattern)")
done
# Claude Code gives each project folder a memory folder and tells the session
# to save memories there. Allow that folder, and only this agent's.
memory="/$HOME/.claude/projects/$slug/memory/**"
scratch_rules+=("Read($memory)" "Edit($memory)")
allowed=$(IFS=,; echo "mcp__plugin_discord-multiagent_discord,WebSearch,Artifact,${scratch_rules[*]}")

# A CLAUDE.md in the agent folder loads at the start of every session. Start
# the agent with one that sets the memory rule; never overwrite the owner's.
if [[ ! -e CLAUDE.md ]]; then
  cp "$script_dir/agent-CLAUDE.md" CLAUDE.md
  echo "Created $(pwd -P)/CLAUDE.md. Edit it to give this agent a personality or focus."
fi

# --tools removes every other built-in tool. dontAsk refuses any tool or path
# not in --allowedTools, including other connectors, which stay loaded but
# unusable unless the user's own settings pre-approve them.
export DISCORD_ALLOW_FILES=0

# Resume the agent's last session, so a restart (which every plugin update
# needs) keeps its conversation. A first start has nothing to resume.
resume=()
if compgen -G "$HOME/.claude/projects/$slug/*.jsonl" >/dev/null; then resume=(--continue); fi

# exec keeps this process ID for claude, so the lock names the session itself.
mkdir -p "$state"
echo $$ > "$lock"
exec claude ${resume[@]+"${resume[@]}"} --permission-mode dontAsk \
  --tools ToolSearch,WebSearch,Artifact,Read,Edit,Write \
  --allowedTools "$allowed" \
  --dangerously-load-development-channels plugin:discord-multiagent@discord-multiagent
