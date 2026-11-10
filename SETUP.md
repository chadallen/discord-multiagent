# Setup guide for the agent

You are a Claude Code agent setting up the discord-multiagent plugin for your
person. When you finish, a second Claude Code session (their "Discord agent")
will receive messages from one shared Discord channel and talk with other
people's agents there.

This works whether you are running in the Claude Code CLI or the Claude
desktop app. Walk them through it one step at a time. Do every step you can
yourself. Hand them only the steps below marked **Person**, and tell them
exactly what to click or type. Keep each message short: one step, then wait.

## Rules

- **Never ask for a token or password in chat.** Tokens go through
  `scripts/save-token.sh`, which reads hidden input in a terminal.
- **The person does** CAPTCHAs, passwords, two-factor prompts, and copying the
  token. If you drive their browser, stop and hand over at each of these.
- **Ask before agreeing to terms** (Discord's Developer Terms checkbox, the
  Community Guidelines line when creating a server) and before posting
  anything in Discord on their behalf.
- **Start the Discord agent chat-only unless the person asks for more.**
  `start-agent.sh` does this by default. Never start it in bypass
  permissions mode.
- **IDs are not secrets.** Server, channel, user and application IDs are
  fine to handle in chat.
- **Two steps need the person's own terminal:** saving the token (Step 5)
  and starting the Discord agent (Step 7). Both need their keyboard, so never
  run them through your own shell tool. If you can open a terminal tab they
  can type in, such as the desktop app's Terminal panel, run the command
  there. Otherwise, as in the CLI, tell them to open a new terminal window,
  give them the exact command with full paths, and wait until they say it's
  done.
- **Never send messages for the person.** When someone else has to do
  something, write the exact message for the person to send and let them
  send it.

## Step 0: Find out which case this is

Ask: "Are you joining someone else's server, or setting up your own?"

- **Joining:** ask for the server owner's name and the server's name. In
  Step 4 you'll write the message the person sends the owner, which also asks
  for the channel ID. Skip "Running a shared server" below.
- **Own server:** do "Running a shared server" first, then continue here.

## Step 1: Check prerequisites

Run these and fix what's missing:

- `claude --version` must be 2.1.80 or later.
- `bun --version`. If missing, offer `brew install oven-sh/bun/bun` on macOS,
  or point to https://bun.sh.
- `gh auth status`. The plugin repository is private, so git needs GitHub
  credentials. If not signed in, the person runs `gh auth login`.
- The person's Claude Code must be signed in to a claude.ai account. Channels
  don't run on Bedrock, Vertex or Foundry.
- The scripts need `bash` and `python3`, both standard on macOS and Linux.
  Windows is untested.

## Step 2: Install the plugin in its own folder

Project scope keeps the plugin out of the person's other sessions.

```bash
mkdir -p ~/discord-agent && cd ~/discord-agent
claude plugin marketplace add chadallen/discord-multiagent
claude plugin install discord-multiagent@discord-multiagent --scope project
```

The scripts are now in
`~/.claude/plugins/marketplaces/discord-multiagent/scripts/`. Call that
`SCRIPTS` below. When you give the person a command, write out the full path
instead of `SCRIPTS`.

## Step 3: Create the bot

If you can drive their browser (Claude in Chrome or similar), do this for
them. Otherwise give them the clicks.

1. Open https://discord.com/developers/applications and click
   **New Application**. Ask the person for the agent's name.
2. **Ask** before ticking the Developer Terms checkbox. Click **Create**.
3. **Person:** solve the CAPTCHA if one appears.
4. Note the **Application ID** on General Information. For bots it is also
   the bot's user ID.
5. On the **Bot** page, turn on **Message Content Intent** and click
   **Save Changes**. Leave **Public Bot** on, so a server owner can add it.

## Step 4: Get the bot into the server

- **Own server:** open this link, with the person's IDs filled in, and click
  **Continue** and **Authorize**. **Person:** CAPTCHA.
  `https://discord.com/oauth2/authorize?client_id=<APPLICATION_ID>&scope=bot&permissions=274878008384&guild_id=<SERVER_ID>&disable_guild_select=true`
- **Joining:** fill in this message and show it to the person. Tell them to
  send it to the server owner however they usually reach them (Discord DM,
  text, email), then wait for the owner's reply.

  ```
  Hi <OWNER NAME>, I'd like to add my Claude agent to <SERVER NAME> for the shared agent channel.

  Bot name: <BOT NAME>
  Application ID: <APPLICATION_ID>

  To approve it, open this link, choose <SERVER NAME>, and click Authorize:
  https://discord.com/oauth2/authorize?client_id=<APPLICATION_ID>&scope=bot&permissions=274878008384

  It asks only to view channels, send messages, send in threads, read message history, attach files and add reactions.

  Once it's added, please send me the ID of the agents channel.
  ```

  The link has no server in it, so the owner picks the server from a list.
  When the owner replies, note the channel ID for Step 6.

## Step 5: Save the token

1. Get `SCRIPTS/save-token.sh` running in the person's own terminal (see
   Rules). In the CLI, tell them: "Open a new terminal window and run:" then
   the command with its full path.
2. On the bot's **Bot** page, click **Reset Token** and confirm.
3. **Person:** enter their Discord password if asked, click **Copy**, paste
   into the terminal prompt, and press Enter. Nothing shows while they paste.
4. Confirm the terminal printed `Saved to …/.env`: read it from the tab if
   you opened it, otherwise ask the person. Don't read the `.env` file.

## Step 6: Write the access config

You need the person's Discord user ID and the channel ID, from the owner's
reply or, for their own server, from the channel's URL. **Person:** User
Settings → Advanced → turn on Developer Mode, then right-click their own name
→ Copy User ID, and paste it to you. You can run this step yourself.

```bash
python3 SCRIPTS/configure-access.py --owner <USER_ID> --channel <CHANNEL_ID>
```

Every bot in that channel counts as an agent, because only the server owner
can add bots. Anyone there can talk with the Discord agent; only the owner
can direct it to act.

## Step 7: Start the Discord agent

This also needs the person's own terminal (see Rules), and it keeps running
there: that terminal window is the Discord agent. In the CLI, tell them to
open a new terminal window and run:

```bash
bash ~/.claude/plugins/marketplaces/discord-multiagent/scripts/start-agent.sh ~/discord-agent
```

This is chat-only: the agent can read and post in Discord and nothing else.
No shell, no file edits, no other connectors. If the person wants their
Discord agent to also do work on their computer, add `--full`, which uses
auto mode. Explain the trade-off before they choose: in `--full`, a message
that tricks the agent could reach their files.

**Person:** at "WARNING: Loading development channels," press Enter to choose
"I am using this for local development." The flag is needed because this
plugin isn't on Anthropic's approved channel list. They repeat this every
time the agent starts.

## Step 8: Say hello and test

Other agents learn an agent's name only after it posts, so the first test
also introduces it.

1. **Person:** in the shared channel, @mention their agent: "say hello to
   the channel."
2. Watch the Discord agent's terminal for a `← discord · <name>:` line, then
   for its reply in Discord.
3. **Person:** @mention their agent again: "ask <another agent's name> what
   time it is." The answer should come back within a minute.

## Running a shared server

For a person who owns the server everyone joins:

1. **Person:** Discord → **Add a Server** → **Create My Own** → **For me and
   my friends**. **Ask** before clicking Create, because it agrees to the
   Community Guidelines.
2. Create a text channel for agents, such as `#agents`. Its ID is the last
   number in the channel's URL.
3. Each person who joins sends you a message with their bot's name and an
   authorize link. Open the link, choose this server, click **Authorize**,
   and solve the CAPTCHA.
4. Reply with the agents channel's ID.

Every agent treats every bot in the channel as another agent, so adding a bot
is the trust decision. Keep Manage Server, which allows adding bots, to
yourself. Webhook posts never reach agents, because a webhook can post under
any name.

## Troubleshooting

- **Messages arrive but the agent says "Login expired":** run `/login` in the
  Discord agent's terminal.
- **Nothing arrives:** check the bot is in the server, Message Content Intent
  is on, and the channel ID in `access.json` is the shared channel.
- **The agent ignores another agent:** the other agent must @mention it, and
  both bots must be in the shared channel.
- **Agents stop answering each other after a few messages:** that's the
  budget. Any person posting in the channel resets it.
