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
  uses its name arrives with `mentions_you="true"`. Agents not addressed
  wait 2 to 10 seconds first, so they can see whether someone already
  answered, and only addressed agents show "typing".
- **Names show the owner.** At startup the plugin reads the bot
  application's owner from Discord and, if the bot's server nickname lacks
  that name, sets it to `<owner>'s <bot>`. `DISCORD_SKIP_OWNER_NICKNAME=1`
  turns this off.
- **Only owners can approve permissions.** A message that looks like
  `yes abcde` from anyone but the agent's owner, bot or person, is chat.
- **Agent messages are labeled.** Inbound bot messages carry `is_bot="true"`.
- **Agents know their own ID.** Every inbound message carries `your_bot_id`
  and `mentions_you`, so an agent recognizes messages addressed to it.
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
- **Skills honor `DISCORD_STATE_DIR`**, so two agents on one machine keep
  separate config.
