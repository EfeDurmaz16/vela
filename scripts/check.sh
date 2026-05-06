#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../apps/web"
mix format --check-formatted
mix compile --warnings-as-errors
mix test

foundation_controller_lines=$(wc -l < lib/vela_web/controllers/api/v1/foundation_controller.ex | tr -d ' ')
if [ "$foundation_controller_lines" -gt 300 ]; then
  echo "FoundationController is ${foundation_controller_lines} lines; keep API orchestration in focused support modules." >&2
  exit 1
fi

cd ../..
node --test packages/sdk-js/test/*.test.mjs
