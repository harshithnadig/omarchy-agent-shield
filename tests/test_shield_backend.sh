#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_HOME=$(mktemp -d)
TEST_RUNTIME="$TEST_HOME/runtime"
TEST_RUNTIME_SYMLINK="$TEST_HOME/runtime-symlink"
TEST_STATE="$TEST_HOME/state"
mkdir -p "$TEST_RUNTIME" "$TEST_RUNTIME_SYMLINK" "$TEST_STATE"
trap 'rm -rf "$TEST_HOME"' EXIT

output=$(
  HOME="$TEST_HOME" \
  XDG_RUNTIME_DIR="$TEST_RUNTIME" \
  XDG_STATE_HOME="$TEST_STATE" \
  TOKENSHIELD_DIR="$TEST_HOME/no-token-shield" \
  bash "$ROOT_DIR/shield-backend.sh" status
)

jq -e '
  .omniroute.active == false and
  .codex.status == "unavailable" and
  ((.telemetry.gpu_temp == null) or (.telemetry.gpu_temp | type == "number")) and
  ((.telemetry.gpu_power == null) or (.telemetry.gpu_power | type == "number")) and
  (.telemetry.thermal_state | type == "string")
' >/dev/null <<<"$output"

ln -s "$TEST_HOME/redirect" "$TEST_RUNTIME_SYMLINK/tokenshield"
if HOME="$TEST_HOME" XDG_RUNTIME_DIR="$TEST_RUNTIME_SYMLINK" XDG_STATE_HOME="$TEST_STATE" TOKENSHIELD_DIR="$TEST_HOME/no-token-shield" bash "$ROOT_DIR/shield-backend.sh" status >/dev/null 2>&1; then
  echo "symlinked runtime directory was accepted" >&2
  exit 1
fi

echo "Agent Shield backend smoke test passed"
