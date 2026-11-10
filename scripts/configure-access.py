#!/usr/bin/env python3
"""Writes the plugin's access.json for one shared channel.

Sets the owner (whose messages count as instructions), opens one guild
channel with mentions required, and admits other agents by role or bot ID.
Keeps any other channels already configured.
"""
import argparse
import json
import os

parser = argparse.ArgumentParser()
parser.add_argument("--owner", required=True, help="your Discord user ID")
parser.add_argument("--channel", required=True, help="shared channel ID")
parser.add_argument("--role", action="append", default=[], help="role ID that marks agent bots")
parser.add_argument("--bot", action="append", default=[], help="another agent's bot user ID")
parser.add_argument("--state-dir", default=os.environ.get(
    "DISCORD_STATE_DIR", os.path.expanduser("~/.claude/channels/discord-multiagent")))
a = parser.parse_args()

for value in [a.owner, a.channel, *a.role, *a.bot]:
    if not value.isdigit():
        parser.error(f"{value!r} is not a Discord ID (digits only)")

os.makedirs(a.state_dir, mode=0o700, exist_ok=True)
path = os.path.join(a.state_dir, "access.json")
try:
    with open(path) as f:
        access = json.load(f)
except FileNotFoundError:
    access = {"dmPolicy": "allowlist", "allowFrom": [], "groups": {}, "pending": {}}

access["dmPolicy"] = "allowlist"
access["allowFrom"] = sorted(set(access.get("allowFrom", [])) | {a.owner})
group = access.setdefault("groups", {}).setdefault(a.channel, {})
group["requireMention"] = True
group.setdefault("allowFrom", [])
group["allowBotRoles"] = sorted(set(group.get("allowBotRoles", [])) | set(a.role))
group["allowBots"] = sorted(set(group.get("allowBots", [])) | set(a.bot))

tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(access, f, indent=2)
    f.write("\n")
os.chmod(tmp, 0o600)
os.replace(tmp, path)
print(f"Wrote {path}")
print(json.dumps({"owner": access["allowFrom"], "channel": a.channel, **group}, indent=2))
