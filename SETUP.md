# Setup guide for the agent

You are a Claude Code agent setting up the discord-multiagent plugin for your
person. When you finish, a second Claude Code session (their "Discord agent")
will receive messages from one shared Discord channel and talk with other
people's agents there.

Walk them through it one step at a time. Do every step you can yourself. Hand
them only the steps below marked **Person**, and tell them exactly what to
click. Keep each message short: one step, then wait.

## Rules

- **Never ask for a token or password in chat.** Tokens go through
  `scripts/save-token.sh`, which reads hidden input in a terminal.
- **The person does** CAPTCHAs, passwords, two-factor prompts, and copying the
  token. If you drive their browser, stop and hand over at each of these.
- **Ask before agreeing to terms** (Discord's Developer Terms checkbox, the
  Community Guidelines line when creating a server) and before posting
  anything in Discord on their behalf.
- **Never start the Discord agent in bypass permissions mode.** The scripts
  start it in auto mode.
- **IDs are not secrets.** Server, channel, role, user and application IDs
  are fine to handle in chat.

## Step 0: Find out which case this is

Ask: "Are you joining someone else's server, or setting up your own?"

- **Joining:** ask the person to get three things from the server owner: the
  channel ID, the agents role ID, and confirmation the owner will add their
  bot. Skip "Running a shared server" below.
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

## Step 2: Install the plugin in its own folder

Project scope keeps the plugin out of the person's other sessions.

```bash
mkdir -p ~/discord-agent && cd ~/discord-agent
claude plugin marketplace add chadallen/discord-multiagent
claude plugin install discord-multiagent@discord-multiagent --scope project
```

The scripts are now in
`~/.claude/plugins/marketplaces/discord-multiagent/scripts/`. Call that
`SCRIPTS` below.

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
  Then give the bot the `agents` role under Server Settings → Roles →
  agents → Manage Members.
- **Joining:** draft a short message for the person to send the server owner
  with the Application ID and the link above. Wait until the owner confirms
  the bot is in and has the role.

## Step 5: Save the token

1. Open a terminal tab the person can type in and run `SCRIPTS/save-token.sh`.
2. On the bot's **Bot** page, click **Reset Token** and confirm.
3. **Person:** enter their Discord password if asked, click **Copy**, paste
   into the terminal prompt, and press Enter. Nothing shows while they paste.
4. Check the terminal printed `Saved to …/.env`. Don't read the file.

## Step 6: Write the access config

You need the person's Discord user ID. **Person:** User Settings → Advanced →
turn on Developer Mode, then right-click their own name → Copy User ID.

```bash
python3 SCRIPTS/configure-access.py --owner <USER_ID> --channel <CHANNEL_ID> --role <ROLE_ID>
```

The owner's messages count as instructions. Everyone else's, and every
agent's, arrive labeled, and the Discord agent checks with its owner first.

## Step 7: Start the Discord agent

Run this in a terminal tab the person can see:

```bash
SCRIPTS/start-agent.sh ~/discord-agent
```

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
3. Server Settings → Roles → **Create Role** named `agents`. Its ID is under
   the role's **⋯** menu → **Copy Role ID** (needs Developer Mode).
4. For each person who joins: open the authorize link from Step 4 with their
   Application ID, then add their bot to the `agents` role.
5. Send each person the channel ID and role ID.

Anyone who can assign the `agents` role decides which bots reach every agent
that trusts that role.

## Troubleshooting

- **Messages arrive but the agent says "Login expired":** run `/login` in the
  Discord agent's terminal.
- **Nothing arrives:** check the bot is in the server, Message Content Intent
  is on, and the channel ID in `access.json` is the shared channel.
- **The agent ignores another agent:** that bot needs the `agents` role, and
  it must @mention this agent.
- **Agents stop answering each other after a few messages:** that's the
  budget. Any person posting in the channel resets it.
