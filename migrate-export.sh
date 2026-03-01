#!/usr/bin/env bash
# =============================================================================
# migrate-export.sh
# Run this on your CURRENT Mac to package everything for migration.
# =============================================================================

set -euo pipefail

EXPORT_DIR="$HOME/openclaw-export"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=============================================="
echo " OpenClaw Migration — Export"
echo " $(date)"
echo "=============================================="
echo ""

mkdir -p "$EXPORT_DIR"

# --- OpenClaw config + all workspaces ---
echo "[1/4] Archiving ~/.openclaw/ ..."
tar -czf "$EXPORT_DIR/openclaw-config-$TIMESTAMP.tar.gz" \
  --exclude="$HOME/.openclaw/workspace*/node_modules" \
  -C "$HOME" .openclaw
echo "      ✓ Saved: openclaw-config-$TIMESTAMP.tar.gz"

# --- Agent dashboard ---
if [ -d "$HOME/agent-dashboard" ]; then
  echo "[2/4] Archiving ~/agent-dashboard/ ..."
  tar -czf "$EXPORT_DIR/agent-dashboard-$TIMESTAMP.tar.gz" \
    --exclude="$HOME/agent-dashboard/node_modules" \
    -C "$HOME" agent-dashboard
  echo "      ✓ Saved: agent-dashboard-$TIMESTAMP.tar.gz"
else
  echo "[2/4] ~/agent-dashboard/ not found — skipping"
fi

# --- Voice interface (note: venv is excluded intentionally) ---
VOICE_DIR="$HOME/.openclaw/workspace/voice_interface"
if [ -d "$VOICE_DIR" ]; then
  echo "[3/4] Archiving voice_interface/ (excluding venv) ..."
  tar -czf "$EXPORT_DIR/voice-interface-$TIMESTAMP.tar.gz" \
    --exclude="$VOICE_DIR/venv" \
    -C "$(dirname "$VOICE_DIR")" voice_interface
  echo "      ✓ Saved: voice-interface-$TIMESTAMP.tar.gz"
  echo "      ⚠  NOTE: venv is excluded — rebuild it on the Mac Mini with setup-voice.sh"
else
  echo "[3/4] voice_interface/ not found — skipping"
fi

# --- Manifest ---
echo "[4/4] Writing manifest ..."
cat > "$EXPORT_DIR/MANIFEST.txt" << EOF
OpenClaw Migration Export
Generated: $(date)
Source host: $(hostname)
macOS version: $(sw_vers -productVersion)
Node version: $(node --version 2>/dev/null || echo "not found")
OpenClaw version: $(openclaw --version 2>/dev/null || echo "not found")

Files:
$(ls -lh "$EXPORT_DIR")

Notes:
- venv directories are EXCLUDED — rebuild with setup-voice.sh on the new machine
- node_modules are EXCLUDED — run 'npm install' in agent-dashboard/ after restore
- Google OAuth token (google-token.json) may need refresh after migration
- Audio device indices in voice_interface.py may need updating on new hardware
- Mac Mini has NO built-in mic — external USB mic required for voice interface
EOF
echo "      ✓ Saved: MANIFEST.txt"

echo ""
echo "=============================================="
echo " Export complete! Files are in: $EXPORT_DIR"
echo ""
echo " Next steps:"
echo "   1. Transfer $EXPORT_DIR/ to your Mac Mini"
echo "      (AirDrop, scp, USB drive, etc.)"
echo "   2. On the Mac Mini, run: bash migrate-import.sh"
echo "   3. For voice interface: bash setup-voice.sh"
echo "=============================================="
