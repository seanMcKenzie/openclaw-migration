#!/usr/bin/env bash
# =============================================================================
# migrate-import.sh
# Run this on the NEW MAC to restore everything from the export archives.
# Place this script in the same folder as the export archives.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE_BIN=""

echo "=============================================="
echo " OpenClaw Migration — Import"
echo " $(date)"
echo "=============================================="
echo ""

# --- Preflight checks ---
echo "[preflight] Checking prerequisites..."

MISSING=0
check_cmd() {
  if command -v "$1" &>/dev/null; then
    echo "  ✓ $1 ($(command -v $1))"
  else
    echo "  ✗ $1 NOT FOUND"
    MISSING=1
  fi
}

check_cmd brew
check_cmd node
check_cmd npm
check_cmd python3
check_cmd git

if [ "$MISSING" -eq 1 ]; then
  echo ""
  echo "  Fix missing prerequisites:"
  echo "    brew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  echo "    node: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash"
  echo "          source ~/.zshrc && nvm install 22.22.0 && nvm alias default 22.22.0"
  echo "    git:  xcode-select --install"
  echo ""
  exit 1
fi

NODE_BIN="$(command -v node)"
echo "  Node binary: $NODE_BIN"
echo ""

# --- Find archives ---
OPENCLAW_ARCHIVE=$(ls "$SCRIPT_DIR"/openclaw-config-*.tar.gz 2>/dev/null | sort | tail -1 || true)
DASHBOARD_ARCHIVE=$(ls "$SCRIPT_DIR"/agent-dashboard-*.tar.gz 2>/dev/null | sort | tail -1 || true)
PROJECT_ARCHIVE=$(ls "$SCRIPT_DIR"/project-dashboard-*.tar.gz 2>/dev/null | sort | tail -1 || true)
PLIST_ARCHIVE=$(ls "$SCRIPT_DIR"/launchd-plists-*.tar.gz 2>/dev/null | sort | tail -1 || true)

if [ -z "$OPENCLAW_ARCHIVE" ]; then
  echo "ERROR: No openclaw-config-*.tar.gz found in $SCRIPT_DIR"
  exit 1
fi

echo "Found archives:"
echo "  OpenClaw config: $(basename $OPENCLAW_ARCHIVE)"
[ -n "$DASHBOARD_ARCHIVE" ] && echo "  Agent dashboard: $(basename $DASHBOARD_ARCHIVE)" || echo "  Agent dashboard: not found"
[ -n "$PROJECT_ARCHIVE" ]   && echo "  Project dashboard: $(basename $PROJECT_ARCHIVE)" || echo "  Project dashboard: not found"
[ -n "$PLIST_ARCHIVE" ]     && echo "  launchd plists: $(basename $PLIST_ARCHIVE)" || echo "  launchd plists: not found (will create from scratch)"
echo ""

# --- [1/7] Restore ~/.openclaw ---
echo "[1/7] Restoring ~/.openclaw/ (all workspaces + memories + credentials)..."
if [ -d "$HOME/.openclaw" ]; then
  BACKUP="$HOME/.openclaw.bak.$(date +%Y%m%d_%H%M%S)"
  echo "      Existing ~/.openclaw found — backing up to $BACKUP"
  mv "$HOME/.openclaw" "$BACKUP"
fi
tar -xzf "$OPENCLAW_ARCHIVE" -C "$HOME"
echo "      ✓ ~/.openclaw/ restored"
echo "      ✓ All agent workspaces restored (K2S0, Charlie, Dennis, Mac, Frank, Sweet Dee, Cricket)"
echo "      ✓ All MEMORY.md files, SOUL.md, AGENTS.md preserved"

# --- [2/7] Restore agent dashboard ---
if [ -n "$DASHBOARD_ARCHIVE" ]; then
  echo "[2/7] Restoring ~/agent-dashboard/ ..."
  [ -d "$HOME/agent-dashboard" ] && mv "$HOME/agent-dashboard" "$HOME/agent-dashboard.bak.$(date +%Y%m%d_%H%M%S)"
  tar -xzf "$DASHBOARD_ARCHIVE" -C "$HOME"
  echo "      Installing npm dependencies..."
  cd "$HOME/agent-dashboard" && npm install --silent
  cd "$SCRIPT_DIR"
  echo "      ✓ ~/agent-dashboard/ restored + npm install done"
else
  echo "[2/7] No agent-dashboard archive — skipping"
fi

# --- [3/7] Restore project dashboard (with live data) ---
if [ -n "$PROJECT_ARCHIVE" ]; then
  echo "[3/7] Restoring ~/project-dashboard/ (includes dashboard.db with all projects, tasks, sprints)..."
  [ -d "$HOME/project-dashboard" ] && mv "$HOME/project-dashboard" "$HOME/project-dashboard.bak.$(date +%Y%m%d_%H%M%S)"
  tar -xzf "$PROJECT_ARCHIVE" -C "$HOME"
  echo "      Installing npm dependencies..."
  cd "$HOME/project-dashboard" && npm install --silent
  cd "$SCRIPT_DIR"
  echo "      ✓ ~/project-dashboard/ restored"
  DB_SIZE=$(du -sh "$HOME/project-dashboard/dashboard.db" 2>/dev/null | cut -f1 || echo "not found")
  echo "      ✓ dashboard.db restored ($DB_SIZE) — MedSales project + Sprint 1 data preserved"
else
  echo "[3/7] No project-dashboard archive — skipping"
fi

# --- [4/7] Install system dependencies ---
echo "[4/7] Installing system dependencies..."

install_if_missing() {
  if brew list "$1" &>/dev/null 2>&1; then
    echo "  ✓ $1 already installed"
  else
    echo "  Installing $1..."
    brew install "$1"
  fi
}
install_if_missing sox
install_if_missing portaudio

if ! command -v mmdc &>/dev/null; then
  echo "  Installing Mermaid CLI..."
  npm install -g @mermaid-js/mermaid-cli --silent
else
  echo "  ✓ mmdc already installed"
fi

# --- [5/7] Install OpenClaw ---
echo "[5/7] Installing OpenClaw..."
npm install -g openclaw --silent
echo "      ✓ OpenClaw installed: $(openclaw --version 2>/dev/null || echo 'check manually')"

# --- [6/7] Set up launchd auto-start ---
echo "[6/7] Setting up launchd auto-start services..."

PLIST_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$PLIST_DIR"

if [ -n "$PLIST_ARCHIVE" ]; then
  echo "  Restoring launchd plists from archive..."
  # Extract to temp, then update node paths for new machine
  TMP_PLIST=$(mktemp -d)
  tar -xzf "$PLIST_ARCHIVE" -C "$TMP_PLIST" 2>/dev/null || true
  # Copy plists, fixing node path to match this machine's node
  for PLIST in "$TMP_PLIST"/**/*.plist "$TMP_PLIST"/*.plist; do
    [ -f "$PLIST" ] && cp "$PLIST" "$PLIST_DIR/" 2>/dev/null || true
  done
  # Update node binary paths in all copied plists
  for PLIST in \
    "$PLIST_DIR/ai.k2s0.agent-dashboard.plist" \
    "$PLIST_DIR/ai.k2s0.project-dashboard.plist"; do
    if [ -f "$PLIST" ]; then
      # Replace old node path with new machine's node path
      sed -i '' "s|/Users/.*/\.nvm/versions/node/[^/]*/bin/node|$NODE_BIN|g" "$PLIST"
      # Replace old username in paths
      OLD_USER=$(grep -o '/Users/[^/]*' "$PLIST" | head -1 | cut -d/ -f3 || echo "")
      NEW_USER=$(whoami)
      if [ -n "$OLD_USER" ] && [ "$OLD_USER" != "$NEW_USER" ]; then
        sed -i '' "s|/Users/$OLD_USER/|/Users/$NEW_USER/|g" "$PLIST"
      fi
    fi
  done
  rm -rf "$TMP_PLIST"
  echo "  ✓ Plists restored and updated with new machine paths"
else
  echo "  No plist archive — creating launchd plists from scratch..."
  # Agent dashboard
  cat > "$PLIST_DIR/ai.k2s0.agent-dashboard.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>ai.k2s0.agent-dashboard</string>
  <key>ProgramArguments</key>
  <array>
    <string>$NODE_BIN</string>
    <string>$HOME/agent-dashboard/server.js</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$HOME/agent-dashboard</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/agent-dashboard.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/agent-dashboard.err</string>
</dict>
</plist>
PLIST

  # Project dashboard
  cat > "$PLIST_DIR/ai.k2s0.project-dashboard.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>ai.k2s0.project-dashboard</string>
  <key>ProgramArguments</key>
  <array>
    <string>$NODE_BIN</string>
    <string>$HOME/project-dashboard/server.js</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$HOME/project-dashboard</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/project-dashboard.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/project-dashboard.err</string>
</dict>
</plist>
PLIST
  echo "  ✓ Plists created"
fi

# Load the services
for LABEL in ai.k2s0.agent-dashboard ai.k2s0.project-dashboard; do
  PLIST="$PLIST_DIR/$LABEL.plist"
  if [ -f "$PLIST" ]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    launchctl load "$PLIST" 2>/dev/null && echo "  ✓ $LABEL loaded" || echo "  ⚠  $LABEL failed to load (check plist)"
  fi
done

# --- [7/7] Verify ---
echo "[7/7] Verifying..."
sleep 3
AGENT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3131 2>/dev/null || echo "000")
PROJECT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3232 2>/dev/null || echo "000")

[ "$AGENT_STATUS" = "200" ] && echo "  ✅ Agent dashboard — http://localhost:3131 (LIVE)" || echo "  ⚠  Agent dashboard — not responding yet (check /tmp/agent-dashboard.log)"
[ "$PROJECT_STATUS" = "200" ] && echo "  ✅ Project dashboard — http://localhost:3232 (LIVE)" || echo "  ⚠  Project dashboard — not responding yet (check /tmp/project-dashboard.log)"

echo ""
echo "=============================================="
echo " Restore complete!"
echo ""
echo " Dashboards:"
echo "   Agent Dashboard   → http://localhost:3131"
echo "   Project Dashboard → http://localhost:3232"
echo ""
echo " Next steps:"
echo "   1. Run: openclaw gateway start"
echo "   2. Verify: openclaw status"
echo "   3. Voice interface: bash setup-voice.sh"
echo "      (requires external USB mic on Mac Mini)"
echo "   4. If Google Drive OAuth fails, re-auth:"
echo "      rm ~/.openclaw/google-token.json"
echo "      python3 ~/.openclaw/workspace/auth_gdrive.py"
echo "=============================================="
