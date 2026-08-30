#!/usr/bin/env bash
# 🛡️ Agent Quota Shield Visual Plugin Backend
set -euo pipefail

PID_FILE="/tmp/omniroute_rag_gateway.pid"
GATEWAY_DIR="$HOME/Work/omniroute-rag-gateway"

is_omniroute_active() {
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

get_status_json() {
  local omni_active=false
  if is_omniroute_active; then
    omni_active=true
  fi

  local compact_limit=12000
  if [[ -f "$HOME/.codex/config.toml" ]]; then
    compact_limit=$(grep 'auto_compact_token_limit' "$HOME/.codex/config.toml" | grep -o '[0-9]*' || echo 12000)
  fi

  local mode="Default (12k)"
  if [[ "$compact_limit" -le 8000 ]]; then
    mode="Super Lean (8k)"
  elif [[ "$compact_limit" -ge 16000 ]]; then
    mode="Balanced (16k)"
  fi

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
    "status": "Protected"
  },
  "antigravity": {
    "status": "Active",
    "caching": "Enabled"
  }
}
JSON
}

cmd="${1:-status}"
case "$cmd" in
  toggle-omniroute)
    if is_omniroute_active; then
      local pid=$(cat "$PID_FILE" 2>/dev/null || true)
      kill "$pid" 2>/dev/null || true
      rm -f "$PID_FILE" 2>/dev/null || true
    else
      cd "$GATEWAY_DIR"
      python3 rag_compressor.py >/dev/null 2>&1 &
      echo $! > "$PID_FILE"
    fi
    get_status_json
    ;;
  set-mode)
    local target="${2:-12000}"
    if [[ -f "$HOME/.codex/config.toml" ]]; then
      sed -i "s/auto_compact_token_limit = .*/auto_compact_token_limit = $target/" "$HOME/.codex/config.toml"
    fi
    get_status_json
    ;;
  open-dashboard)
    if command -v foot &>/dev/null; then
      nohup foot --hold python3 "$GATEWAY_DIR/dashboard.py" >/dev/null 2>&1 &
    elif command -v kitty &>/dev/null; then
      nohup kitty --hold python3 "$GATEWAY_DIR/dashboard.py" >/dev/null 2>&1 &
    elif command -v alacritty &>/dev/null; then
      nohup alacritty -e python3 "$GATEWAY_DIR/dashboard.py" >/dev/null 2>&1 &
    fi
    get_status_json
    ;;
  *)
    get_status_json
    ;;
esac
