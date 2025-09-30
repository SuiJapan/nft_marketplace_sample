#!/usr/bin/env bash
set -euo pipefail

if command -v pnpm >/dev/null 2>&1; then
  pnpm install --prefer-offline --ignore-scripts >/dev/null 2>&1 || true
fi
