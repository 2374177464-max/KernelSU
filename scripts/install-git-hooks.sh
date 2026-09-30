#!/bin/sh
# Point this clone at the repository's tracked git hooks (.githooks/).
#
# Run once per clone:
#
#     scripts/install-git-hooks.sh
#
# The hooks live in .githooks/ so they are versioned with the fork; git only
# needs to be told where to find them.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

git -C "$REPO_ROOT" config core.hooksPath .githooks
chmod +x "$REPO_ROOT/.githooks/"* 2>/dev/null || true

echo "git hooks installed (core.hooksPath=.githooks)"
echo "post-commit will now refresh the .ksu-fork-offset cache automatically."