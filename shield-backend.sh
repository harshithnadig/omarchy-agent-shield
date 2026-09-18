#!/usr/bin/env bash
# 🛡️ TokenShield Visual Plugin Backend with Real-Time Hardware Sentinel
set -euo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/tokenshield"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tokenshield"

ensure_private_directory() {
  local directory="$1"
  local owner

  if [[ -L "$directory" || ( -e "$directory" && ! -d "$directory" ) ]]; then
    echo "Refusing unsafe runtime path: $directory" >&2
    return 1
  fi
  if [[ ! -d "$directory" ]]; then
    (umask 077; mkdir "$directory")
  fi
  if [[ -L "$directory" || ! -d "$directory" ]]; then
    echo "Refusing unsafe runtime path: $directory" >&2
    return 1
  fi
  owner=$(stat -c '%u' -- "$directory" 2>/dev/null || true)
  if [[ -z "$owner" ]]; then
    owner=$(stat -f '%u' -- "$directory" 2>/dev/null || true)
  fi
  if [[ "$owner" != "$(id -u)" ]]; then
    echo "Refusing runtime directory not owned by the current user: $directory" >&2
    return 1
  fi
  chmod 0700 -- "$directory"
}

ensure_private_directory "$RUNTIME_DIR"
mkdir -p -- "$(dirname "$STATE_DIR")"
ensure_private_directory "$STATE_DIR"

PID_FILE="$RUNTIME_DIR/tokenshield.pid"
TELEMETRY_FILE="$STATE_DIR/telemetry.json"
if [[ -n "${TOKENSHIELD_DIR:-}" ]]; then
  TOKENSHIELD_DIR="$TOKENSHIELD_DIR"
elif [[ -d "$HOME/Work/tokenshield" ]]; then
  TOKENSHIELD_DIR="$HOME/Work/tokenshield"
else
  TOKENSHIELD_DIR="$HOME/.local/share/tokenshield"
fi
GATEWAY_SCRIPT="$TOKENSHIELD_DIR/rag_compressor.py"
DASHBOARD_SCRIPT="$TOKENSHIELD_DIR/dashboard.py"

process_is_gateway() {
  local pid="$1"
  local cmdline

  [[ -r "/proc/$pid/cmdline" ]] || return 1
  cmdline=$(tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null || true)
  grep -Fqx -- "$GATEWAY_SCRIPT" <<<"$cmdline"
}

write_pid_file() {
  local pid="$1"
  local temporary

  if [[ -d "$PID_FILE" ]]; then
    echo "Refusing to overwrite a PID directory: $PID_FILE" >&2
    return 1
  fi
  temporary=$(mktemp "$RUNTIME_DIR/.tokenshield.pid.XXXXXX")
  chmod 0600 -- "$temporary"
  printf '%s\n' "$pid" >"$temporary"
  mv -f -- "$temporary" "$PID_FILE"
}

is_tokenshield_active() {
  if [[ -f "$PID_FILE" && ! -L "$PID_FILE" ]]; then
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null || true)
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
      if process_is_gateway "$pid"; then
        return 0
      fi
    fi
  fi
  return 1
}

get_gpu_vitals() {
  # Read GPU vitals safely via nvidia-smi if available, without arbitrary code execution
  local temp="null"
  local power="null"
  local state="UNKNOWN"

  if command -v nvidia-smi >/dev/null 2>&1; then
    local nv_out
    nv_out=$(nvidia-smi --query-gpu=temperature.gpu,power.draw --format=csv,noheader,nounits 2>/dev/null | head -n 1 || true)
    if [[ -n "$nv_out" ]]; then
      local nv_temp nv_power
      nv_temp=$(echo "$nv_out" | awk -F',' '{print $1}' | tr -d ' ')
      nv_power=$(echo "$nv_out" | awk -F',' '{print $2}' | tr -d ' ')
      if [[ "$nv_temp" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        temp="$nv_temp"
        if awk "BEGIN { exit !($nv_temp > 80) }"; then
          state="THROTTLED"
        elif awk "BEGIN { exit !($nv_temp > 70) }"; then
          state="WARM"
        else
          state="COOL"
        fi
      fi
      if [[ "$nv_power" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        power="$nv_power"
      fi
    fi
  fi

  printf '{"gpu_temp": %s, "gpu_power": %s, "thermal_state": "%s"}' "$temp" "$power" "$state"
}

get_status_json() {
  local omni_active=false
  if is_tokenshield_active; then
    omni_active=true
  fi

  local compact_limit=12000
  local config_status="unavailable"
  if [[ -f "$HOME/.codex/config.toml" ]]; then
    config_status="available"
    compact_limit=$(grep -E '^[[:space:]]*auto_compact_token_limit[[:space:]]*=' "$HOME/.codex/config.toml" | head -n 1 | grep -o '[0-9][0-9]*' | head -n 1 || true)
    [[ "$compact_limit" =~ ^[0-9]+$ ]] || compact_limit=12000
  fi

  local mode="Default (12k)"
  if (( compact_limit <= 8000 )); then
    mode="Super Lean (8k)"
  elif (( compact_limit >= 16000 )); then
    mode="Balanced (16k)"
  fi

  # Data-only telemetry interface (no dynamic imports from external directories).
  # Reject symlinks and oversized/malformed state before embedding it in JSON.
  local telem_json="{}"
  if [[ -f "$TELEMETRY_FILE" && ! -L "$TELEMETRY_FILE" ]]; then
    local telemetry_size
    telemetry_size=$(stat -c '%s' -- "$TELEMETRY_FILE" 2>/dev/null || echo 1048577)
    if [[ "$telemetry_size" =~ ^[0-9]+$ ]] && (( telemetry_size <= 1048576 )); then
      local candidate
      candidate=$(cat -- "$TELEMETRY_FILE" 2>/dev/null || true)
      if jq -e -c 'type == "object"' >/dev/null 2>&1 <<<"$candidate"; then
        telem_json=$(jq -c '.' <<<"$candidate")
      fi
    fi
  fi
  if [[ "$telem_json" == "{}" ]]; then
    local vitals
    vitals=$(get_gpu_vitals)
    telem_json="$vitals"
  fi

  local antigravity_status="Not detected"
  command -v agy >/dev/null 2>&1 && antigravity_status="Available"

  cat <<JSON
{
  "omniroute": {
    "active": $omni_active,
    "port": 8080,
    "upstream": 20128
  },
  "codex": {
    "compact_limit": $compact_limit,
    "mode": "$mode",
    "status": "$config_status"
  },
  "antigravity": {
    "status": "$antigravity_status"
  },
  "telemetry": $telem_json
}
JSON
}

main() {
  local cmd="${1:-status}"
  case "$cmd" in
    toggle-omniroute)
      if is_tokenshield_active; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
          if process_is_gateway "$pid"; then
            kill "$pid" 2>/dev/null || true
          fi
        fi
        rm -f "$PID_FILE"
      else
        if [[ -f "$GATEWAY_SCRIPT" ]]; then
          python3 "$GATEWAY_SCRIPT" >/dev/null 2>&1 &
          local gateway_pid=$!
          if ! write_pid_file "$gateway_pid"; then
            kill "$gateway_pid" 2>/dev/null || true
            return 1
          fi
        fi
      fi
      get_status_json
      ;;
    set-mode)
      local target="${2:-12000}"
      if [[ "$target" =~ ^[0-9]+$ ]] && [[ -f "$HOME/.codex/config.toml" ]]; then
        sed -i "s/auto_compact_token_limit = .*/auto_compact_token_limit = $target/" "$HOME/.codex/config.toml"
      fi
      get_status_json
      ;;
    open-dashboard)
      if [[ -f "$DASHBOARD_SCRIPT" ]]; then
        nohup foot -T "TokenShield Live Analytics" --hold python3 "$DASHBOARD_SCRIPT" >/dev/null 2>&1 &
      fi
      get_status_json
      ;;
    *)
      get_status_json
      ;;
  esac
}

main "$@"
