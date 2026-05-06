#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

required_files=(
  "README.md"
  "CONTRIBUTING.md"
  "docs/api.md"
  "docs/architecture.md"
  "docs/roadmap.md"
  "docs/security.md"
  "packages/protocol/events.schema.json"
  "packages/protocol/webhook-events.schema.json"
  "packages/protocol/examples/webhooks/merge.queued.json"
  "packages/sdk-js/src/index.js"
  ".github/workflows/ci.yml"
  ".github/ISSUE_TEMPLATE/bug_report.md"
  ".github/ISSUE_TEMPLATE/feature_or_protocol.md"
  ".github/ISSUE_TEMPLATE/security_sensitive.md"
  ".github/pull_request_template.md"
)

missing=0

for file in "${required_files[@]}"; do
  if [[ -f "$file" ]]; then
    printf "ok   %s\n" "$file"
  else
    printf "MISS %s\n" "$file" >&2
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

printf "\nLatest commits:\n"
git log --oneline -n 12

printf "\nWorking tree:\n"
git status --short --branch

printf "\nStatus documentation headings:\n"
grep -nE "^## (Status Matrix|Shipped|In Progress|Planned|Not Phase|Threat Model|Auth And Idempotency)" \
  README.md docs/roadmap.md docs/security.md docs/api.md

printf "\nRun ./scripts/check.sh for compile, test and SDK verification.\n"
