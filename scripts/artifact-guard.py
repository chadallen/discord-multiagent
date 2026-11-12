#!/usr/bin/env python3
"""Claude Code PreToolUse hook that limits a Discord agent's Artifact tool to
artifacts whose links were posted in its channel.

The Artifact tool acts as the owner's claude.ai account, so without this a
stranger could ask the agent to list, read, overwrite or delete the owner's
other artifacts. The plugin records every artifact link it sees in the channel
in artifact-links.txt; anything else is refused. Any error refuses too.
Usage (set by start-agent.sh): artifact-guard.py <path to artifact-links.txt>
"""
import json
import re
import sys

ARTIFACT_URL = re.compile(r"claude\.ai/(?:code/)?(?:public/)?artifacts?/([A-Za-z0-9_-]{8,})")
REFUSED = {"list", "delete", "pin", "unpin"}


def deny(reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }}))
    sys.exit(0)


def artifact_id(url):
    m = ARTIFACT_URL.search(str(url))
    return m.group(1).lower() if m else None


def main():
    data = json.load(sys.stdin)
    if data.get("tool_name") != "Artifact":
        return
    args = data.get("tool_input") or {}
    try:
        with open(sys.argv[1]) as f:
            known = {line.strip() for line in f if line.strip()}
    except OSError:
        known = set()

    def unlinked(url):
        return url and artifact_id(url) not in known

    not_linked = ("Only artifacts whose links were posted in this Discord channel can be "
                  "opened or changed. Ask whoever shared it to post the link in the channel.")
    action = args.get("action") or "publish"
    if action in REFUSED:
        deny(f"The Artifact tool's {action} action is turned off for Discord agents.")
    if action == "quickstart":
        return
    if action in ("read", "open"):
        if action == "open" and not args.get("url"):
            deny(not_linked)
        if unlinked(args.get("url")):
            deny(not_linked)
        return
    if action == "publish":
        # A publish without url creates a new artifact, which is allowed.
        if unlinked(args.get("url")) or unlinked(args.get("from_url")):
            deny(not_linked)
        files = args.get("files") or {}
        sources = files.values() if isinstance(files, dict) else files
        for src in sources:
            if isinstance(src, dict) and unlinked(src.get("artifact")):
                deny(not_linked)
        return
    deny(f"The Artifact tool's {action} action is turned off for Discord agents.")


try:
    main()
except SystemExit:
    raise
except Exception as err:  # noqa: BLE001 - any failure must refuse, not allow
    deny(f"Artifact check failed, so the call was refused: {err}")
