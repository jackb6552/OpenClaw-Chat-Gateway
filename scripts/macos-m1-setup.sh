#!/bin/bash
set -euo pipefail

CLAWUI_PORT="${1:-3115}"
OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs/OpenClaw-Chat-Gateway"
CLAWUI_LABEL="cc.angeworld.clawui.${CLAWUI_PORT}"
OPENCLAW_LABEL="cc.openclaw.gateway.${OPENCLAW_GATEWAY_PORT}"
CLAWUI_PLIST="$LAUNCH_AGENT_DIR/${CLAWUI_LABEL}.plist"
OPENCLAW_PLIST="$LAUNCH_AGENT_DIR/${OPENCLAW_LABEL}.plist"

export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This setup script is intended for macOS only."
  exit 1
fi

if [ "$(uname -m)" != "arm64" ]; then
  echo "Warning: this script is optimized for Apple Silicon, current arch: $(uname -m)"
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing command: $1"
    echo "Please install it first and re-run this script."
    exit 1
  fi
}

plist_escape() {
  printf '%s' "$1" \
    | sed -e 's/&/\&amp;/g' \
          -e 's/</\&lt;/g' \
          -e 's/>/\&gt;/g' \
          -e 's/"/\&quot;/g' \
          -e "s/'/\&apos;/g"
}

stop_launch_agent_if_loaded() {
  local label="$1"
  local plist="$2"
  if launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
    launchctl bootout "gui/$(id -u)" "$plist" 2>/dev/null || true
  fi
}

start_launch_agent() {
  local label="$1"
  local plist="$2"
  launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null || true
  launchctl kickstart -k "gui/$(id -u)/$label" || true
}

wait_for_port() {
  local port="$1"
  local label="$2"
  local seconds="${3:-25}"
  for _ in $(seq 1 "$seconds"); do
    if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
      echo "$label is listening on port $port"
      return 0
    fi
    sleep 1
  done
  echo "Warning: $label did not start listening on port $port within ${seconds}s"
  return 1
}

require_cmd git
require_cmd node
require_cmd npm
require_cmd launchctl
require_cmd lsof

mkdir -p "$LAUNCH_AGENT_DIR" "$LOG_DIR"

if ! command -v openclaw >/dev/null 2>&1; then
  echo "OpenClaw CLI was not found in PATH."
  echo "Current PATH: $PATH"
  echo "Install or repair OpenClaw first, then re-run this script."
  exit 1
fi

cd "$PROJECT_ROOT"

echo "Installing dependencies and building OpenClaw Chat Gateway..."
npm install --include=dev
(cd backend && npm install --include=dev)
(cd frontend && npm install --include=dev)
npm run build

if [ -f "$HOME/.openclaw/openclaw.json" ]; then
  echo "Patching local OpenClaw config for loopback control UI..."
  node backend/patch-config.js || true
else
  echo "Warning: ~/.openclaw/openclaw.json was not found. OpenClaw gateway may not be initialized yet."
fi

OPENCLAW_CMD="$(command -v openclaw)"
NODE_CMD="$(command -v node)"
ESCAPED_PATH="$(plist_escape "$PATH")"
ESCAPED_HOME="$(plist_escape "$HOME")"
ESCAPED_PROJECT_ROOT="$(plist_escape "$PROJECT_ROOT")"
ESCAPED_OPENCLAW_CMD="$(plist_escape "$OPENCLAW_CMD")"
ESCAPED_NODE_CMD="$(plist_escape "$NODE_CMD")"

stop_launch_agent_if_loaded "$OPENCLAW_LABEL" "$OPENCLAW_PLIST"
cat > "$OPENCLAW_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$OPENCLAW_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$ESCAPED_OPENCLAW_CMD</string>
    <string>gateway</string>
    <string>run</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key>
    <string>$ESCAPED_HOME</string>
    <key>PATH</key>
    <string>$ESCAPED_PATH</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$ESCAPED_HOME/Library/Logs/OpenClaw-Chat-Gateway/openclaw-gateway.out.log</string>
  <key>StandardErrorPath</key>
  <string>$ESCAPED_HOME/Library/Logs/OpenClaw-Chat-Gateway/openclaw-gateway.err.log</string>
</dict>
</plist>
EOF
start_launch_agent "$OPENCLAW_LABEL" "$OPENCLAW_PLIST"

stop_launch_agent_if_loaded "$CLAWUI_LABEL" "$CLAWUI_PLIST"
cat > "$CLAWUI_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$CLAWUI_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$ESCAPED_NODE_CMD</string>
    <string>dist/index.js</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$ESCAPED_PROJECT_ROOT/backend</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PORT</key>
    <string>$CLAWUI_PORT</string>
    <key>NODE_ENV</key>
    <string>production</string>
    <key>CLAWUI_DATA_DIR</key>
    <string>.clawui_release</string>
    <key>HOME</key>
    <string>$ESCAPED_HOME</string>
    <key>PATH</key>
    <string>$ESCAPED_PATH</string>
    <key>OPENCLAW_BIN</key>
    <string>$ESCAPED_OPENCLAW_CMD</string>
    <key>CLAWUI_GITHUB_REPOSITORY</key>
    <string>jackb6552/OpenClaw-Chat-Gateway</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$ESCAPED_HOME/Library/Logs/OpenClaw-Chat-Gateway/clawui-$CLAWUI_PORT.out.log</string>
  <key>StandardErrorPath</key>
  <string>$ESCAPED_HOME/Library/Logs/OpenClaw-Chat-Gateway/clawui-$CLAWUI_PORT.err.log</string>
</dict>
</plist>
EOF
start_launch_agent "$CLAWUI_LABEL" "$CLAWUI_PLIST"

wait_for_port "$OPENCLAW_GATEWAY_PORT" "OpenClaw gateway" 25 || true
wait_for_port "$CLAWUI_PORT" "OpenClaw Chat Gateway" 25 || true

cat <<EOF

Done.

OpenClaw native gateway:
  ws://127.0.0.1:$OPENCLAW_GATEWAY_PORT

OpenClaw Chat Gateway panel:
  http://localhost:$CLAWUI_PORT

Status commands:
  launchctl print gui/$(id -u)/$OPENCLAW_LABEL
  launchctl print gui/$(id -u)/$CLAWUI_LABEL

Logs:
  tail -f ~/Library/Logs/OpenClaw-Chat-Gateway/openclaw-gateway.err.log
  tail -f ~/Library/Logs/OpenClaw-Chat-Gateway/clawui-$CLAWUI_PORT.err.log

EOF
