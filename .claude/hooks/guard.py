#!/usr/bin/env python3
"""Blocks agent actions that need the owner, before they run.

Claude Code calls this as a PreToolUse hook for Bash, Edit and Write. Exit
code 2 blocks the call and shows stderr to the agent. These rules back up
AGENTS.md section 5; an instruction file is followed most of the time, a
hook every time.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys

SECRET_FILE = re.compile(r"(^|[\s/'\"=<>])(\.dev\.vars(\.\w+)?|\.env(\.(?!example\b|sample\b)\w+)?)(?![\w.])")
# A git command at the start of a shell command, with optional `-C dir` flags.
GIT = r"(?:^|[;&|(]\s*)git(?:\s+-C\s+\S+)*\s+"

BASH_RULES = [
    (re.compile(GIT + r"push\b[^;&|]*(\s--force\b|\s-f\b|\s--force-with-lease\b|\s\+\S)"),
     "Force-pushing rewrites shared history. Ask the owner."),
    (re.compile(GIT + r"push\b[^;&|]*\s(\S+:)?(main|master)(\s|$)"),
     "Pushing to main needs the owner. Push a feature branch and open a pull request."),
    (re.compile(r"\bwrangler\s+deploy\b(?![^;&|]*--dry-run)"),
     "Deploys run from CI with the owner's token, not from an agent session."),
    (re.compile(r"\bwrangler\s+(d1\s+(migrations\s+apply|execute)|secret\s+(put|delete|bulk))\b[^;&|]*--remote"),
     "Remote D1 changes and secrets are owner actions."),
    (re.compile(r"\bwrangler\s+secret\s+(put|delete|bulk)\b"),
     "Secrets are set by the owner or CI, never by an agent."),
    (re.compile(r"\brm\s+-[a-zA-Z]*r[a-zA-Z]*f?\s+(/|~|\$HOME|\.git)(\s|$|/)"),
     "Refusing to delete the root, home or .git directory."),
    (re.compile(r"(sed\s+-i|>\s*|tee\s+)[^;&|]*spec/v4\.0/"),
     "spec/v4.0/ is the normative bundle and is never edited; record changes in spec/errata/."),
]


def agent_identity() -> bool:
    """True when git would record an AI agent as the commit author."""
    email = subprocess.run(["git", "config", "user.email"], capture_output=True, text=True).stdout
    name = subprocess.run(["git", "config", "user.name"], capture_output=True, text=True).stdout
    return "anthropic.com" in email or "openai.com" in email or name.strip().lower() in {"claude", "codex"}


def current_branch() -> str:
    return subprocess.run(["git", "rev-parse", "--abbrev-ref", "HEAD"], capture_output=True, text=True).stdout.strip()


def deny(reason: str) -> int:
    print(f"Blocked by .claude/hooks/guard.py: {reason}", file=sys.stderr)
    return 2


def main() -> int:
    event = json.load(sys.stdin)
    tool = event.get("tool_name", "")
    tool_input = event.get("tool_input", {})

    if tool == "Bash":
        command = tool_input.get("command", "")
        for pattern, reason in BASH_RULES:
            if pattern.search(command):
                return deny(reason)
        if SECRET_FILE.search(command):
            return deny("Local secret files (.dev.vars, .env) stay out of agent sessions.")
        if re.search(GIT + r"push\b", command) and current_branch() in {"main", "master"}:
            return deny("You are on main; pushing it needs the owner. Work on a feature branch.")
        if re.search(GIT + r"commit\b", command) and agent_identity():
            return deny("Commits are authored by the owner, never an agent. Run: "
                        "git config --global user.name 'Hristo Hristov' && "
                        "git config --global user.email '91317021+Milkeles@users.noreply.github.com'")
        return 0

    if tool in ("Edit", "Write", "MultiEdit"):
        path = tool_input.get("file_path", "")
        if re.search(r"(^|/)spec/v4\.0/", path):
            return deny("spec/v4.0/ is never edited; record changes in spec/errata/.")
        if SECRET_FILE.search(path):
            return deny("Local secret files (.dev.vars, .env) stay out of agent sessions.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
