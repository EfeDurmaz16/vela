#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../apps/web"
mix deps.get
mix ecto.setup
