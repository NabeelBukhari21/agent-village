#!/bin/bash
# Start the Agent Village server automatically when you log in to your Mac.
#
#   server/autostart.sh install    # install and start now
#   server/autostart.sh uninstall  # stop and remove
#   server/autostart.sh status     # is it running? where are the logs?
#
# Uses a per-user LaunchAgent (no admin rights needed). Logs go to
# ~/AgentVillageServer/server.log.

set -euo pipefail

LABEL="com.agentvillage.server"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SCRIPT="$(cd "$(dirname "$0")" && pwd)/village_server.py"
PYTHON="$(command -v python3)"
CLAUDE_DIR="$(dirname "$(command -v claude || echo /opt/homebrew/bin/claude)")"
LOG="$HOME/AgentVillageServer/server.log"
DOMAIN="gui/$(id -u)"

install() {
  mkdir -p "$HOME/Library/LaunchAgents" "$HOME/AgentVillageServer"
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$PYTHON</string>
    <string>-u</string>
    <string>$SCRIPT</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$CLAUDE_DIR:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>WorkingDirectory</key><string>$HOME/AgentVillageServer</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>10</integer>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF
  launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
  launchctl bootstrap "$DOMAIN" "$PLIST"
  echo "Installed. The server now starts whenever you log in."
  echo "Pairing code: $(cat "$HOME/AgentVillageServer/pairing.token" 2>/dev/null || echo '(created on first start — see the log)')"
  echo "Log: $LOG"
}

uninstall() {
  launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "Removed. The server will no longer start automatically."
}

status() {
  if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
    echo "Auto-start: installed"
    launchctl print "$DOMAIN/$LABEL" | grep -E "state =|pid =" | sed 's/^/  /'
  else
    echo "Auto-start: not installed"
  fi
  echo "Log: $LOG"
  tail -n 8 "$LOG" 2>/dev/null || true
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  status) status ;;
  *) echo "Usage: $0 install|uninstall|status"; exit 1 ;;
esac
