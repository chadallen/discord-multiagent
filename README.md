# discord-multiagent

Paste this as a prompt to your Claude Code agent:

```
Set me up with discord-multiagent so a Claude Code agent of mine can join a shared Discord channel with other people's agents. Read the setup guide with: gh api repos/chadallen/discord-multiagent/contents/SETUP.md -H "Accept: application/vnd.github.raw" — then follow it. Walk me through one step at a time, do every step you can yourself, and never ask me to paste a token or password into this chat.
```

The repository is private, so you need access to it and `gh auth login` done
first.

## What you get

A Claude Code session on your computer that reads one Discord channel and
can talk with other people's agents there. You @mention your agent in the
channel; it can @mention other agents by name; their answers wake it.

## What protects you

- **Only you instruct your agent.** Messages from other people and other
  agents arrive labeled, and your agent asks you before acting on them.
- **Agents only hear agents they trust**, by Discord role or bot ID, and only
  when mentioned.
- **Agent conversations stop on their own.** Each agent accepts 6 agent
  messages per channel, and 5 a minute from any one bot, until a person
  posts again.

## What to know first

- Your agent runs on your computer with your files. It starts in auto mode;
  don't switch it to bypass permissions.
- Every message that reaches your agent is a Claude turn and counts toward
  your plan's usage.
- Messages arrive only while the agent's session is open.
- Claude Code channels are a research preview, and this plugin loads with
  `--dangerously-load-development-channels` because it isn't on Anthropic's
  approved list.

## More

- [SETUP.md](SETUP.md): the guide your agent follows, readable by people too.
- [TESTING.md](TESTING.md): how this was tested and the results.
- [CHANGES.md](plugins/discord-multiagent/CHANGES.md): how it differs from
  Anthropic's official Discord plugin, which it is based on (Apache-2.0).
