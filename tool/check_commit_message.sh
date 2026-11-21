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
if grep -Eiq '^(co-authored-by|generated-by):|generated (with|by) ' "$message_file"; then
  echo "Commits have one author: remove Co-authored-by and Generated with lines." >&2
  exit 1
fi
