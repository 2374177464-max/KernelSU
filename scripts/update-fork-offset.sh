#!/bin/sh
# Refresh the cached .ksu-fork-offset: how many commits this fork adds over
# upstream.
#
# Upstream computes KSU_VERSION = 30000 + (official commit count). This fork has
# extra commits, so counting HEAD alone overshoots and the reported version would
# run ahead of upstream. Subtracting the fork-only commit count restores it.
#
# The build systems compute this offset live from git and only fall back to this
# cached file when the official branch is not reachable (CI checkouts of the
# fork, source tarballs). The cache is refreshed by .githooks/post-commit; run
# this by hand after fetching upstream:
#
#     scripts/update-fork-offset.sh
#
# Exits non-zero when the official ref is missing; the existing cache is then
# left untouched.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
OFFSET_FILE="$REPO_ROOT/.ksu-fork-offset"

GIT=$(command -v git 2>/dev/null || true)
if [ -z "$GIT" ]; then
    for candidate in /usr/bin/git /usr/local/bin/git; do
        [ -x "$candidate" ] && GIT=$candidate && break
    done
fi
if [ -z "$GIT" ]; then
    echo "update-fork-offset: git not found" >&2
    exit 1
fi

OFFICIAL_REFS=${KSU_OFFICIAL_REFS:-upstream/main upstream/master}

official_ref=
for ref in $OFFICIAL_REFS; do
    if "$GIT" -C "$REPO_ROOT" rev-parse --verify --quiet "$ref^{commit}" >/dev/null 2>&1; then
        official_ref=$ref
        break
    fi
done

if [ -z "$official_ref" ]; then
    echo "update-fork-offset: no official ref (tried: $OFFICIAL_REFS)" >&2
    echo "    git remote add upstream https://github.com/tiann/KernelSU.git" >&2
    exit 1
fi

offset=$("$GIT" -C "$REPO_ROOT" rev-list --count "$official_ref..HEAD" 2>/dev/null || true)
case "$offset" in
    ''|*[!0-9]*)
        echo "update-fork-offset: cannot count fork commits" >&2
        exit 1
        ;;
esac

official_count=$("$GIT" -C "$REPO_ROOT" rev-list --count "$official_ref" 2>/dev/null || echo 0)
upstream_version=$(expr 30000 + "$official_count")

if [ -f "$OFFSET_FILE" ] && [ "$(cat "$OFFSET_FILE")" = "$offset" ]; then
    echo "fork offset cache: $offset (unchanged; upstream version $upstream_version)"
    exit 0
fi

printf '%s\n' "$offset" > "$OFFSET_FILE"
echo "fork offset cache: $offset (upstream version $upstream_version)"