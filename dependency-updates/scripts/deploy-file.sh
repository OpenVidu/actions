#!/usr/bin/env bash
# Create or update a file in a repo via the API (handles the SHA if it exists)
set -euo pipefail
FULL_REPO="$1"; DEST="$2"; SRC="$3"; MSG="$4"

SHA=$(gh api "repos/$FULL_REPO/contents/$DEST" -q .sha 2>/dev/null || true)

ARGS=(-X PUT "repos/$FULL_REPO/contents/$DEST"
      -f message="$MSG"
      -f content="$(base64 -w0 "$SRC")")
[ -n "$SHA" ] && ARGS+=(-f sha="$SHA")

gh api "${ARGS[@]}" --silent
