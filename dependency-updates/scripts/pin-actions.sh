#!/usr/bin/env bash
# Resolve the <SHA_*> tokens used by the dependency-update machinery into full
# 40-char commit SHAs.
#
# Two targets, because tokens appear in two places:
#   1. The repo's own reusable workflows (.github/workflows/renovate-*.yml).
#      Resolved IN PLACE and committed - they run from there.
#   2. dependency-updates/templates/ -> dependency-updates/build/, the files
#      deployed into each managed repo. Never deploy from templates/, always
#      from build/.
#
# Templates carry tokens instead of hashes so a stale hash can never ship.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"   # dependency-updates/
ROOT="$(cd "$HERE/.." && pwd)"             # repository root
cd "$HERE"

# repo | desired tag | token used in the templates and workflows
PINS=(
  "actions/checkout|v6.0.2|SHA_CHECKOUT"
  "actions/create-github-app-token|v2|SHA_APP_TOKEN"
  "renovatebot/github-action|v43|SHA_RENOVATE"
  "anthropics/claude-code-action|v1|SHA_CLAUDE"
)

rm -rf build && mkdir -p build
cp templates/* build/

IN_PLACE=("$ROOT/.github/workflows/renovate-run.yml" "$ROOT/.github/workflows/renovate-ai-fix.yml")

for entry in "${PINS[@]}"; do
  IFS='|' read -r repo tag token <<< "$entry"

  sha=$(gh api "repos/$repo/commits/$tag" --jq .sha)
  [ "${#sha}" -eq 40 ] || { echo "Invalid SHA for $repo@$tag"; exit 1; }

  # Confirm the SHA belongs to the upstream repo, not a fork
  gh api "repos/$repo/commits/$sha" --silent \
    || { echo "SHA not found in $repo"; exit 1; }

  echo "  $repo@$tag -> $sha"
  sed -i "s|<$token>|$sha|g" build/* "${IN_PLACE[@]}"
done

# Fail if any token is left unresolved
if grep -rn "<SHA_" build/ "${IN_PLACE[@]}" ; then
  echo "❌ Unresolved tokens remain"; exit 1
fi

# Fail if any action is still referenced by tag. Reusable workflows are exempt
# from the SHA-pinning policy, so references to them are filtered out by the
# shape of the reference itself (owner/repo/.github/workflows/...).
if grep -rnE "uses: [A-Za-z0-9._-]+/[A-Za-z0-9._-]+@(v?[0-9]|main|master)" \
     build/*.yml "${IN_PLACE[@]}" | grep -vE "uses: [A-Za-z0-9._-]+/[A-Za-z0-9._-]+/\.github/workflows/" ; then
  echo "❌ Actions still referenced by tag"; exit 1
fi

echo "✅ build/ ready and reusable workflows pinned"
