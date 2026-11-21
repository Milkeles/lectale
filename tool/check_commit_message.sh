#!/usr/bin/env bash
# Checks a commit message: a Conventional Commits subject, and one author per
# commit, so no Co-authored-by trailers and no "Generated with" footers.
# Pairing is credited in the pull request instead.
#
# Usage: tool/check_commit_message.sh <file with the message>
set -euo pipefail

message_file="$1"
subject=$(head -n 1 "$message_file")
types='build|chore|ci|deps|docs|feat|fix|perf|refactor|revert|style|test'

if [[ "$subject" =~ ^(Merge|Revert|fixup!|squash!) ]]; then
  exit 0
fi
if ! [[ "$subject" =~ ^($types)(\([a-z0-9-]+\))?!?:\ [^[:space:]] ]]; then
  echo "The subject is not a Conventional Commit: $subject" >&2
  echo "Use <type>(<scope>): <description>, with type one of: ${types//|/, }." >&2
  exit 1
fi
if (( ${#subject} > 72 )); then
  echo "The subject is longer than 72 characters." >&2
  exit 1
fi
# The owner allows exactly one co-author: Claude, whose noreply address is
# linked to GitHub's `claude` account (decision of 2026-11-21).
if grep -Ei '^co-authored-by:' "$message_file" | grep -Eivq '^co-authored-by: claude[^<]*<noreply@anthropic\.com>$'; then
  echo "The only allowed co-author is: Co-authored-by: Claude <noreply@anthropic.com>." >&2
  exit 1
fi
if grep -Eiq '^generated-by:|generated (with|by) ' "$message_file"; then
  echo "Remove Generated with/by lines." >&2
  exit 1
fi
