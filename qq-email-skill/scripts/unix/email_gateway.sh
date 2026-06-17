#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER_JS="${SCRIPT_DIR}/../engine_runner.cjs"

if ! command -v node >/dev/null 2>&1; then
  echo '{"success":false,"error_code":2,"message":"未检测到 node，无法运行 qq-email-skill"}'
  exit 1
fi

exec node "${RUNNER_JS}" "$@"
