#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../apps/web"
mix format --check-formatted
mix compile --warnings-as-errors
mix test
