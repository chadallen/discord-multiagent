#!/usr/bin/env bash
# Starts a chat-only Claude Code session that receives Discord messages
# through the plugin. The only tools that exist are the plugin's, web search,
# claude.ai artifacts, and file tools limited to the session's own scratch
# folder, where the Artifact tool keeps its working copies. Anything else is
# refused without asking, and the plugin can't attach or download files. So
# a message can't get the agent to touch the computer or the owner's other
# accounts.
# Usage: start-agent.sh <agent-folder> [state-dir]
set -euo pipefail
folder=${1:?usage: start-agent.sh <agent-folder> [state-dir]}
if [[ -n ${2:-} ]]; then export DISCORD_STATE_DIR="$2"; fi
cd "$folder"

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
allowed=$(IFS=,; echo "mcp__plugin_discord-multiagent_discord,WebSearch,Artifact,${scratch_rules[*]}")

# --tools removes every other built-in tool. dontAsk refuses any tool or path
# not in --allowedTools, including other connectors, which stay loaded but
# unusable unless the user's own settings pre-approve them.
export DISCORD_ALLOW_FILES=0
exec claude --permission-mode dontAsk \
  --tools ToolSearch,WebSearch,Artifact,Read,Edit,Write \
  --allowedTools "$allowed" \
  --dangerously-load-development-channels plugin:discord-multiagent@discord-multiagent
