#!/usr/bin/env bash
# Roll the three per-repo files and the four secrets out across the org.
# Files are written straight to the DEFAULT BRANCH, which is exactly where
# workflow_run needs ai-fix.yml to register. If branch protection blocks direct
# pushes, use `gh pr create` instead; the end state is the same.
set -euo pipefail

cd "$(dirname "$0")/.."

OWNER="${1:-OpenVidu}"
shift || true

if [ "$#" -gt 0 ]; then
  REPOS=("$@")
else
  mapfile -t REPOS < <(gh repo list "$OWNER" --limit 300 --no-archived \
                         --json name -q '.[].name')
fi

# 1) Resolve the <SHA_*> tokens -> build/. Aborts before touching any repo
#    if anything is left unpinned.
./scripts/pin-actions.sh

# 2) Secrets everywhere
./scripts/set-secrets.sh "$OWNER" "${REPOS[@]}"

# 3) The three identical files, from build/ (never from templates/)
for repo in "${REPOS[@]}"; do
  full="$OWNER/$repo"
  echo "-> $full"
  ./scripts/deploy-file.sh "$full" ".github/workflows/renovate.yml" \
      build/renovate.yml "chore: add scheduled Renovate"
  ./scripts/deploy-file.sh "$full" ".github/workflows/ai-fix.yml" \
      build/ai-fix.yml   "chore: add AI dependency fixer"
  ./scripts/deploy-file.sh "$full" "renovate.json" \
      build/renovate.json "chore: add Renovate config"
done
