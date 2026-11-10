# Changes from the official discord plugin

Based on `external_plugins/discord` in anthropics/claude-plugins-official
(commit dceb15d, Apache-2.0). Changed files: `server.ts`, both skills,
`plugin.json`, `README.md`, `ACCESS.md`.

- **Renamed** to `discord-multiagent`. Commands are `/discord-multiagent:*`
  and the default state folder is `~/.claude/channels/discord-multiagent`,
  so it never reads or writes the official plugin's config.
- **Other bots can get in.** A guild channel can list bot user IDs in
  `allowBots`. A listed bot's message is delivered only if it @mentions this
  bot, and each bot is capped at 5 messages a minute
  (`DISCORD_BOT_MAX_PER_MINUTE`). Unlisted bots and all bot DMs are dropped.
- **Bots can't approve permissions.** A bot message that looks like
  `yes abcde` is treated as chat, never as a permission reply.
- **Agent messages are labeled.** Inbound bot messages carry `is_bot="true"`,
  and the server instructions tell Claude to treat them as suggestions.
- **Agents know their own ID.** Every inbound message carries `your_bot_id`
  and `mentions_you`, so an agent recognizes messages addressed to it.
- **Agents find each other by name.** Every inbound message in a channel with
  `allowBots` carries `other_agents`, a list of `name=<@id>` pairs, so a
  person can write "ask Agent B" without the bot's ID.
- **Agent exchanges have a budget.** Each agent accepts at most 6 agent
  messages per channel (`DISCORD_BOT_TURNS_PER_HUMAN`) until a human posts
  there again. The rate limit alone let two agents loop indefinitely.
- **Other people are labeled.** In guild channels, human messages carry
  `from_owner="true"` for people on `allowFrom` and `"false"` for everyone
  else, and the instructions tell Claude to act only on its owner's.
- **Bots can be allowed by role.** `allowBotRoles` admits any bot holding a
  listed role, so adding an agent doesn't mean editing every other agent's
  config. `group role add|rm` manages it, and `group add` now keeps a
  channel's bot lists.
- **Agents get the conversation, not just the tag.** Each pushed message
  carries `recent_messages`: what was said since that agent last posted, up
  to 20 messages (`DISCORD_CONTEXT_MESSAGES`, 0 turns it off).
- **History is labeled.** `recent_messages` and `fetch_messages` mark each
  sender as owner, person, agent, untrusted bot or you, from config, and show
  mentions as names. One message can't forge another's line.
- **`reply` checks its input**, so a missing `text` returns an error the
  agent can fix instead of crashing.
- **Skills honor `DISCORD_STATE_DIR`**, so two agents on one machine keep
  separate config. The access skill adds `group bot add|rm`.
