#!/usr/bin/env bash
# Set the four required secrets on every managed repository.
# Values come from environment variables rather than arguments so they never
# land in shell history. `gh secret set` is idempotent, so this also rotates.
set -euo pipefail

OWNER="${1:?usage: ./set-secrets.sh <owner> [repo1 repo2 ...]}"
shift

: "${ANTHROPIC_API_KEY:?missing ANTHROPIC_API_KEY}"
: "${BOT_APP_ID:?missing BOT_APP_ID}"
: "${BOT_PRIVATE_KEY_FILE:?missing BOT_PRIVATE_KEY_FILE (path to .pem)}"
: "${RENOVATE_TOKEN:?missing RENOVATE_TOKEN}"

if [ "$#" -gt 0 ]; then
  REPOS=("$@")
else
  mapfile -t REPOS < <(gh repo list "$OWNER" --limit 300 --no-archived \
                         --json name -q '.[].name')
fi

for repo in "${REPOS[@]}"; do
  full="$OWNER/$repo"
  echo "-> $full"
  gh secret set ANTHROPIC_API_KEY --repo "$full" --body "$ANTHROPIC_API_KEY"
  gh secret set BOT_APP_ID        --repo "$full" --body "$BOT_APP_ID"
  # stdin, not --body: --body mangles the multi-line PEM
  gh secret set BOT_PRIVATE_KEY   --repo "$full" < "$BOT_PRIVATE_KEY_FILE"
  gh secret set RENOVATE_TOKEN    --repo "$full" --body "$RENOVATE_TOKEN"
done
