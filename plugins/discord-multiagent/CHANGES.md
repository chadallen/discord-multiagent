# Changes from the official discord plugin

Based on `external_plugins/discord` in anthropics/claude-plugins-official
(commit dceb15d, Apache-2.0). Changed files: `server.ts`, both skills,
`plugin.json`, `README.md`, `ACCESS.md`.

- **Renamed** to `discord-multiagent`. Commands are `/discord-multiagent:*`
  and the default state folder is `~/.claude/channels/discord-multiagent`,
  so it never reads or writes the official plugin's config.
- **Other agents can get in.** Every bot in an opted-in guild channel counts
  as an agent, because adding a bot to the server takes the owner's
  approval. Its message is delivered only if it @mentions this bot, and each
  bot is capped at 5 messages a minute (`DISCORD_BOT_MAX_PER_MINUTE`).
  Webhook posts and bot DMs are dropped.
- **Bots can't approve permissions.** A bot message that looks like
  `yes abcde` is treated as chat, never as a permission reply.
- **Agent messages are labeled.** Inbound bot messages carry `is_bot="true"`.
- **Agents know their own ID.** Every inbound message carries `your_bot_id`
  and `mentions_you`, so an agent recognizes messages addressed to it.
- **Agents find each other by name.** Every inbound message carries
  `other_agents`, the bots that have posted in the channel as `name=<@id>`
  pairs, so a person can write "ask Agent B" without the bot's ID.
- **Agent exchanges have a budget.** Each agent accepts at most 6 agent
  messages per channel (`DISCORD_BOT_TURNS_PER_HUMAN`) until a human posts
  there again. The rate limit alone let two agents loop indefinitely.
- **Other people are labeled.** In guild channels, human messages carry
  `from_owner="true"` for people on `allowFrom` and `"false"` for everyone
  else.
- **Anyone can talk, only the owner can direct.** The instructions let an
  agent answer anyone's questions, and require its owner's OK before it acts
  on the computer or accounts, shares anything private, or speaks for the
  owner.
- **Agents get the conversation, not just the tag.** Each pushed message
  carries `recent_messages`: what was said since that agent last posted, up
  to 20 messages (`DISCORD_CONTEXT_MESSAGES`, 0 turns it off).
- **History is labeled.** `recent_messages` and `fetch_messages` mark each
  sender as owner, person, agent, webhook or you, from config, and show
  mentions as names. One message can't forge another's line.
- **`reply` checks its input**, so a missing `text` returns an error the
  agent can fix instead of crashing.
- **Skills honor `DISCORD_STATE_DIR`**, so two agents on one machine keep
  separate config.
