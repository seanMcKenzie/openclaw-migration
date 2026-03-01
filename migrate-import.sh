#!/usr/bin/env bash
# =============================================================================
# migrate-import.sh
# Run this on the MAC MINI to restore everything from the export archives.
# Expects export archives in the same directory as this script.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=============================================="
echo " OpenClaw Migration — Import"
echo " $(date)"
echo "=============================================="
echo ""

# --- Preflight checks ---
echo "[preflight] Checking prerequisites..."

check_cmd() {
  if command -v "$1" &>/dev/null; then
    echo "  ✓ $1 found"
  else
    echo "  ✗ $1 NOT found — install it before continuing"
    MISSING=1
  fi
}

MISSING=0
check_cmd brew
check_cmd node
check_cmd npm
check_cmd python3
check_cmd git

if [ "$MISSING" -eq 1 ]; then
  echo ""
  echo "  Fix missing prerequisites first:"
  echo "    brew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  echo "    node: install nvm → nvm install 22.22.0"
  echo "    git:  xcode-select --install"
  echo ""
  exit 1
fi

echo ""

# --- Find archives ---
OPENCLAW_ARCHIVE=$(ls "$SCRIPT_DIR"/openclaw-config-*.tar.gz 2>/dev/null | sort | tail -1 || true)
DASHBOARD_ARCHIVE=$(ls "$SCRIPT_DIR"/agent-dashboard-*.tar.gz 2>/dev/null | sort | tail -1 || true)

if [ -z "$OPENCLAW_ARCHIVE" ]; then
  echo "ERROR: No openclaw-config-*.tar.gz found in $SCRIPT_DIR"
  exit 1
fi

# --- Restore ~/.openclaw ---
echo "[1/5] Restoring ~/.openclaw/ ..."
if [ -d "$HOME/.openclaw" ]; then
  echo "      Existing ~/.openclaw found — backing it up first..."
  mv "$HOME/.openclaw" "$HOME/.openclaw.bak.$(date +%Y%m%d_%H%M%S)"
fi
tar -xzf "$OPENCLAW_ARCHIVE" -C "$HOME"
echo "      ✓ ~/.openclaw/ restored"

# --- Restore agent dashboard ---
if [ -n "$DASHBOARD_ARCHIVE" ]; then
  echo "[2/5] Restoring ~/agent-dashboard/ ..."
  if [ -d "$HOME/agent-dashboard" ]; then
    mv "$HOME/agent-dashboard" "$HOME/agent-dashboard.bak.$(date +%Y%m%d_%H%M%S)"
  fi
  tar -xzf "$DASHBOARD_ARCHIVE" -C "$HOME"
  echo "[3/5] Installing agent-dashboard npm dependencies..."
  cd "$HOME/agent-dashboard"
  npm install
  cd "$SCRIPT_DIR"
  echo "      ✓ ~/agent-dashboard/ restored + npm install done"
else
  echo "[2/5] No agent-dashboard archive found — skipping"
  echo "[3/5] Skipping npm install (no dashboard)"
fi

# --- Install system dependencies ---
echo "[4/5] Installing system dependencies..."

if ! command -v sox &>/dev/null; then
  echo "      Installing sox..."
  brew install sox
else
  echo "      ✓ sox already installed"
fi

if ! command -v portaudio &>/dev/null && ! brew list portaudio &>/dev/null 2>&1; then
  echo "      Installing portaudio (required for PyAudio)..."
  brew install portaudio
else
  echo "      ✓ portaudio already installed"
fi

if ! command -v mmdc &>/dev/null; then
  echo "      Installing Mermaid CLI..."
  npm install -g @mermaid-js/mermaid-cli
else
  echo "      ✓ mmdc already installed"
fi

# --- Install OpenClaw ---
echo "[5/5] Installing OpenClaw..."
CURRENT_VERSION=$(openclaw --version 2>/dev/null || echo "not installed")
echo "      Current: $CURRENT_VERSION"
npm install -g openclaw
echo "      ✓ OpenClaw installed: $(openclaw --version 2>/dev/null)"

echo ""
echo "=============================================="
echo " Restore complete!"
echo ""
echo " Next steps:"
echo "   1. Run setup-voice.sh to rebuild the voice interface venv"
echo "   2. Start OpenClaw: openclaw gateway start"
echo "   3. Verify config: openclaw status"
echo "   4. Check audio devices for voice interface (see setup-voice.sh output)"
echo "   5. If Google Drive OAuth fails, re-run: python3 ~/.openclaw/workspace/auth_gdrive.py"
echo "=============================================="
