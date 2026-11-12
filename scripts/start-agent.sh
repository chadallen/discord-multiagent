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
mkdir -p "$folder"
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
# exec keeps this process ID for claude, so the lock names the session itself.
mkdir -p "$state"
echo $$ > "$lock"
exec claude --permission-mode dontAsk \
  --tools ToolSearch,WebSearch,Artifact,Read,Edit,Write \
  --allowedTools "$allowed" \
  --dangerously-load-development-channels plugin:discord-multiagent@discord-multiagent
