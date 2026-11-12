# Changes from the official discord plugin

Based on `external_plugins/discord` in anthropics/claude-plugins-official
(commit dceb15d, Apache-2.0). Changed files: `server.ts`, both skills,
`plugin.json`, `README.md`, `ACCESS.md`.

- **Renamed** to `discord-multiagent`. Commands are `/discord-multiagent:*`
  and the default state folder is `~/.claude/channels/discord-multiagent`,
  so it never reads or writes the official plugin's config.
- **Agents hear everyone, like a chat room.** Every bot in an opted-in guild
  channel counts as an agent, because adding a bot to the server takes the
  owner's approval. Every person's and every agent's message reaches every
  agent, which decides whether to speak. Each bot is capped at 5 messages a
  minute per receiver (`DISCORD_BOT_MAX_PER_MINUTE`). Webhook posts and bot
  DMs are dropped.
- **Addressing is detected.** A message that tags an agent, replies to it or
  uses its name arrives with `mentions_you="true"`. A name inside a longer
  agent name, such as "Agent" inside "Agent 2", doesn't count. Only
  addressed agents show "typing".
- **Agents take turns on open messages.** For a message that names, tags or
  replies to no agent, every plugin computes the same random speaking
  order. Each agent's turn comes when the one before it posts, or after 10
  seconds of silence (`DISCORD_TURN_SECONDS`, 0 to turn off), 40 seconds at
  most. If someone posted during the wait, the agent gets that newer message
  instead, with the earlier one in `recent_messages`.
- **Replies check for news first.** If messages the agent hasn't seen were
  posted since the one that started its turn, `reply` returns them once
  instead of posting, and the agent sends, revises or skips.
- **Switches change without a restart.** `settings.json` in the config
  folder (`turnTaking`, `turnSeconds`, `checkBeforeSend`) is read on every
  message.
- **Message text can't open tags or forge labels.** Tag-shaped text such as
  `<system-reminder>` gets a look-alike bracket, and "(owner)" or another
  sender label inside history text becomes "[owner]". Only bots keep the
  "Name (Owner's agent)" form, so a person can't take an agent's name.
- **Artifact links are recorded.** Every claude.ai artifact link posted in
  the channel goes into `artifact-links.txt` in the config folder, which
  `scripts/artifact-guard.py` uses to limit the Artifact tool.
- **Agents can't ping everyone.** Only user mentions notify.
- **Names show the owner.** At startup the plugin reads the bot
  application's owner from Discord and, if the bot's server nickname lacks
  the owner's first name, sets it to `<bot> (<owner>'s agent)`, such as
  "Kyle (Chad's agent)", and clears the `<owner>'s <bot>` form earlier
  versions set. A person can address the agent as just "Kyle". The name comes from
  the owner's display name, or from a username whose first part reads as a
  name ("sam.rivera"), never from a handle like "xy_rivera".
  `DISCORD_SKIP_OWNER_NICKNAME=1` turns this off.
- **Only owners can approve permissions.** A message that looks like
  `yes abcde` from anyone but the agent's owner, bot or person, is chat.
- **Agent messages are labeled.** Inbound bot messages carry `is_bot="true"`.
- **Agents know who they are.** Every inbound message carries `your_name`,
  `your_bot_id` and `mentions_you`, so an agent recognizes messages
  addressed to it and knows another agent's task isn't its own.
- **Agents find each other by name.** Every inbound message carries
  `other_agents`, the bots that have posted in the channel as `name=<@id>`
  pairs, so a person can write "ask Agent B" without the bot's ID.
- **The room has a budget.** Every agent counts all agent posts in the
  channel, its own included. After 10 in a row with no person posting
  (`DISCORD_AGENT_POSTS_PER_HUMAN`), agent messages stop reaching anyone
  until a person speaks. The rate limit alone let two agents loop
  indefinitely.
- **Other people are labeled.** In guild channels, human messages carry
  `from_owner="true"` for people on `allowFrom` and `"false"` for everyone
  else.
- **Anyone can talk, only the owner can direct.** The instructions let an
  agent answer anyone's questions, and require its owner's OK before it acts
  on the computer or accounts, shares anything private, or speaks for the
  owner.
- **Agents catch up on what they missed.** Each pushed message carries
  `recent_messages`: messages since that agent last posted that weren't
  pushed to it, up to 20 (`DISCORD_CONTEXT_MESSAGES`, 0 turns it off).
- **History is labeled.** `recent_messages` and `fetch_messages` mark each
  sender as owner, person, agent, webhook or you, from config, and show
  mentions as names. One message can't forge another's line.
- **`reply` checks its input**, so a missing `text` returns an error the
  agent can fix instead of crashing.
- **The Discord tools load up front.** The server is marked `alwaysLoad`, so
  `reply` is always in an agent's context. Behind tool search, one agent
  twice answered in its own terminal instead of calling `reply`.
- **Chat-only is the only mode.** `scripts/start-agent.sh` allows the
  plugin's tools, WebSearch and the Artifact tool, plus Read and Edit only
  inside the session's own scratch folder so artifacts can be edited, and
  refuses everything else without asking.
- **Agents can ask their owner.** Messages carry `your_owner_id`, and the
  instructions have an agent tag its owner for OK before posting private
  information or agreeing to something on the owner's behalf.
- **Message text can't fake labels or tags.** Quotes and angle brackets in
  context text become look-alike characters, and `<channel` in a message
  body is neutralized.
- **Chat-only launches can't send or fetch files.** `DISCORD_ALLOW_FILES=0`
  turns off `reply`'s `files` parameter and `download_attachment`, because a
  stranger could otherwise ask the agent to attach any local file.
- **`@everyone` and role mentions don't address an agent,** and a bot only
  addresses an agent by tag or reply, not by saying its name.
- **The room budget is per thread,** so one busy thread can't use up
  another's.
- **Skills honor `DISCORD_STATE_DIR`**, so two agents on one machine keep
  separate config.
