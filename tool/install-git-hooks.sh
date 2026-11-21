#!/bin/sh
# Installs Lectale's plain git hooks and the owner's commit identity for this
# clone. Agent sandboxes reset the global git identity on restart, so the
# identity lives in the repository's own config, and the pre-commit hook
# refuses agent authors even when Claude Code's hooks aren't loaded.
set -e
root=$(git rev-parse --show-toplevel)
hooks=$(git rev-parse --git-common-dir)/hooks
cp "$root/tool/git-hooks/pre-commit" "$hooks/pre-commit"
chmod +x "$hooks/pre-commit"
git config user.name "Hristo Hristov"
git config user.email "91317021+Milkeles@users.noreply.github.com"
echo "Installed the pre-commit hook and the owner's commit identity."
