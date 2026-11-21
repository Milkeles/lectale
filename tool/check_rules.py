#!/usr/bin/env python3
"""Checks Lectale's project rules that a linter can't express.

Each rule protects a security or architecture decision (see AGENTS.md and
docs/adr/). A line can opt out with `rule-ok: <reason>` in a comment; the
reason is then visible in review.

Usage:
  tool/check_rules.py              check every tracked source file
  tool/check_rules.py PATH...      check the given files
  tool/check_rules.py --hook       read a Claude Code PostToolUse event from
                                   stdin and check the edited file; exit 2 on
                                   a violation so the agent sees why
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Third-party viewers that need Material live only here (ADR-0004).
MATERIAL_ALLOWED = "packages/resource_renderers/lib/src/adapters/"

# Hosts the Worker may call. Anything else risks SSRF or leaking data.
WORKER_FETCH_HOSTS = {
    "api.github.com",
    "raw.githubusercontent.com",
    "www.googleapis.com",
    "securetoken.googleapis.com",
    "token.actions.githubusercontent.com",
    "api.stripe.com",
}


@dataclass(frozen=True)
class Rule:
    name: str
    pattern: re.Pattern[str]
    applies: Callable[[str], bool]  # takes the repo-relative POSIX path
    why: str


def _dart(path: str) -> bool:
    return path.endswith(".dart") and not path.startswith("spec/")


def _worker_ts(path: str) -> bool:
    return path.startswith("apps/edge_api/src/") and path.endswith(".ts")


def _source(path: str) -> bool:
    return path.endswith((".dart", ".ts", ".js", ".json", ".jsonc", ".toml", ".yaml", ".yml")) and not path.startswith(("spec/", "docs/", ".claude/"))


RULES = [
    Rule(
        "no-material-in-app-ui",
        re.compile(r"""import\s+['"]package:(flutter/(material|cupertino)\.dart|material_ui/|cupertino_ui/)"""),
        lambda p: _dart(p) and not p.startswith(MATERIAL_ALLOWED),
        "App UI uses devchat_ui only. Material is allowed in " + MATERIAL_ALLOWED + " (ADR-0004).",
    ),
    Rule(
        "lfs-upload-stays-off",
        re.compile(r"LFS_DIRECT_UPLOAD_ENABLED[\"']?\s*[:=]\s*[\"']?(true|1|yes)\b", re.IGNORECASE),
        _source,
        "Direct LFS upload stays disabled until the S1 security proof passes (AGENTS.md, V4-SEC-05).",
    ),
    Rule(
        "no-browser-credential-storage",
        re.compile(r"package:shared_preferences|\blocalStorage\b|\bsessionStorage\b|indexedDB", re.IGNORECASE),
        lambda p: (_dart(p) or p.endswith(".ts")) and not p.startswith("spec/"),
        "No credentials or session data in browser storage (SESSION_SECURITY.md). Mark a non-sensitive use with rule-ok.",
    ),
    Rule(
        "no-dynamic-code-in-worker",
        re.compile(r"\beval\s*\(|\bnew\s+Function\s*\("),
        lambda p: _worker_ts(p) or (p.startswith("apps/edge_api/src/contract/generated/") and p.endswith(".js")),
        "Workers forbid runtime code generation, and course data must never become code.",
    ),
    Rule(
        "no-html-rendering-of-course-content",
        re.compile(r"package:(flutter_html|flutter_widget_from_html|html_widget)|\bHtmlElementView\b"),
        lambda p: _dart(p) and not p.startswith(MATERIAL_ALLOWED),
        "Course content is untrusted; HTML from it is never rendered (V4-SEC-03).",
    ),
]

FETCH_URL = re.compile(r"""fetch\(\s*[`'"]https?://([^/`'"\s:]+)""")
ANY_FETCH = re.compile(r"(?<![\w.])fetch\s*\(")
# The one module allowed to call fetch; it checks every URL against the
# allowlist at runtime, which a static scan of literals cannot do.
FETCH_MODULE = "apps/edge_api/src/net/fetch.ts"
SUPPRESS = re.compile(r"rule-ok:\s*([a-z-]+)\s+\S")


def check_text(path: str, text: str) -> list[str]:
    problems: list[str] = []
    # Settings can span lines in JSONC/TOML, so the LFS flag is checked on the whole file.
    flat = re.sub(r"\s+", " ", text)
    if _source(path) and RULES[1].pattern.search(flat):
        problems.append(f"{path}: [{RULES[1].name}] {RULES[1].why}")
    for number, line in enumerate(text.splitlines(), start=1):
        suppressed = {m.group(1) for m in SUPPRESS.finditer(line)}
        for rule in RULES:
            if rule is RULES[1]:
                continue
            if rule.name not in suppressed and rule.applies(path) and rule.pattern.search(line):
                problems.append(f"{path}:{number}: [{rule.name}] {rule.why}")
        if _worker_ts(path) and path != FETCH_MODULE and "worker-fetch-allowlist" not in suppressed:
            if ANY_FETCH.search(line):
                problems.append(f"{path}:{number}: [worker-fetch-allowlist] Call outbound HTTP through {FETCH_MODULE}, which enforces the host allowlist.")
                continue
        if _worker_ts(path):
            for host in FETCH_URL.findall(line):
                if host not in WORKER_FETCH_HOSTS:
                    problems.append(
                        f"{path}:{number}: [worker-fetch-allowlist] {host} is not an allowed host; "
                        "add it to WORKER_FETCH_HOSTS in tool/check_rules.py with a reason, or don't call it."
                    )
    return problems


def check_paths(paths: list[Path]) -> list[str]:
    problems: list[str] = []
    for path in paths:
        try:
            relative = path.resolve().relative_to(ROOT).as_posix()
        except ValueError:
            continue
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        problems.extend(check_text(relative, text))
    return problems


def tracked_files() -> list[Path]:
    output = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout
    return [ROOT / line for line in output.splitlines() if line]


def main(argv: list[str]) -> int:
    if argv[:1] == ["--hook"]:
        event = json.load(sys.stdin)
        file_path = event.get("tool_input", {}).get("file_path")
        if not file_path:
            return 0
        problems = check_paths([Path(file_path)])
        if problems:
            print("Project rule check failed:\n" + "\n".join(problems), file=sys.stderr)
            return 2
        return 0

    paths = [Path(arg) for arg in argv] if argv else tracked_files()
    problems = check_paths(paths)
    for problem in problems:
        print(problem)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
