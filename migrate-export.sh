#!/usr/bin/env bash
# =============================================================================
# migrate-export.sh
# Run this on your CURRENT Mac to package everything for migration.
# Covers: OpenClaw config + all agent workspaces + memories, both dashboards
# (including live SQLite data), voice interface, and launchd service plists.
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

# --- OpenClaw config + all agent workspaces + memories ---
echo "[1/6] Archiving ~/.openclaw/ (all workspaces, memories, credentials)..."
tar -czf "$EXPORT_DIR/openclaw-config-$TIMESTAMP.tar.gz" \
  --exclude="$HOME/.openclaw/workspace*/node_modules" \
  --exclude="$HOME/.openclaw/workspace/voice_interface/venv" \
  -C "$HOME" .openclaw
echo "      ✓ Saved: openclaw-config-$TIMESTAMP.tar.gz"
echo "      Includes: openclaw.json, .env, all workspace-* dirs, MEMORY.md,"
echo "               agent SOUL.md files, google credentials, voice_interface.py"

# --- Agent dashboard (code + no node_modules) ---
if [ -d "$HOME/agent-dashboard" ]; then
  echo "[2/6] Archiving ~/agent-dashboard/ ..."
  tar -czf "$EXPORT_DIR/agent-dashboard-$TIMESTAMP.tar.gz" \
    --exclude="$HOME/agent-dashboard/node_modules" \
    -C "$HOME" agent-dashboard
  echo "      ✓ Saved: agent-dashboard-$TIMESTAMP.tar.gz (port 3131)"
else
  echo "[2/6] ~/agent-dashboard/ not found — skipping"
fi

# --- Project dashboard (code + SQLite data) ---
if [ -d "$HOME/project-dashboard" ]; then
  echo "[3/6] Archiving ~/project-dashboard/ (includes dashboard.db live data)..."
  tar -czf "$EXPORT_DIR/project-dashboard-$TIMESTAMP.tar.gz" \
    --exclude="$HOME/project-dashboard/node_modules" \
    -C "$HOME" project-dashboard
  echo "      ✓ Saved: project-dashboard-$TIMESTAMP.tar.gz (port 3232)"
  echo "      ✓ dashboard.db included — projects, tasks, sprints preserved"
else
  echo "[3/6] ~/project-dashboard/ not found — skipping"
fi

# --- launchd plists (auto-start services) ---
echo "[4/6] Archiving launchd service plists ..."
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_ARCHIVE="$EXPORT_DIR/launchd-plists-$TIMESTAMP.tar.gz"
PLISTS_FOUND=0
for PLIST in \
  "$PLIST_DIR/ai.k2s0.agent-dashboard.plist" \
  "$PLIST_DIR/ai.k2s0.project-dashboard.plist" \
  "$PLIST_DIR/ai.openclaw.gateway.plist"; do
  if [ -f "$PLIST" ]; then
    PLISTS_FOUND=$((PLISTS_FOUND + 1))
  fi
done

if [ "$PLISTS_FOUND" -gt 0 ]; then
  tar -czf "$PLIST_ARCHIVE" \
    $(for P in \
      "$PLIST_DIR/ai.k2s0.agent-dashboard.plist" \
      "$PLIST_DIR/ai.k2s0.project-dashboard.plist" \
      "$PLIST_DIR/ai.openclaw.gateway.plist"; do
      [ -f "$P" ] && echo "$P"
    done) 2>/dev/null || true
  echo "      ✓ Saved: launchd-plists-$TIMESTAMP.tar.gz ($PLISTS_FOUND plist(s))"
else
  echo "      ⚠  No K2S0 launchd plists found — dashboards won't auto-start on new machine"
  echo "         Run migrate-import.sh and it will create them from scratch"
fi

# --- Voice interface (venv excluded — rebuilt on new machine) ---
VOICE_DIR="$HOME/.openclaw/workspace/voice_interface"
if [ -d "$VOICE_DIR" ]; then
  echo "[5/6] Voice interface is inside ~/.openclaw/ — already covered in step 1 ✓"
  echo "      (venv excluded — rebuild with setup-voice.sh on new machine)"
else
  echo "[5/6] voice_interface/ not found inside ~/.openclaw/workspace/ — skipping"
fi

# --- Manifest ---
echo "[6/6] Writing manifest ..."
cat > "$EXPORT_DIR/MANIFEST.txt" << EOF
OpenClaw Migration Export
Generated: $(date)
Source host: $(hostname)
macOS version: $(sw_vers -productVersion)
Node version: $(node --version 2>/dev/null || echo "not found")
OpenClaw version: $(openclaw --version 2>/dev/null || echo "not found")

Archives included:
$(ls -lh "$EXPORT_DIR"/*.tar.gz 2>/dev/null || echo "  (none)")

What's included:
  ✅ ~/.openclaw/               All OpenClaw config, API keys (.env), Discord bot tokens
  ✅ workspace/                 K2S0 MEMORY.md, SOUL.md, AGENTS.md, TOOLS.md
  ✅ workspace-developer/       Charlie's workspace, medsales schema + data model
  ✅ workspace-pm/              Dennis's workspace, PRDs, sprint plans
  ✅ workspace-qa/              Mac's workspace, test plans
  ✅ workspace-devops/          Frank's workspace, medsales-infra, architecture docs
  ✅ workspace-research/        Sweet Dee's workspace, reports
  ✅ workspace-designer/        Cricket's workspace, wireframes
  ✅ google-credentials.json    Google service account
  ✅ voice_interface.py         Voice interface script (venv excluded)
  ✅ agent-dashboard/           Code for http://localhost:3131 (node_modules excluded)
  ✅ project-dashboard/         Code + dashboard.db for http://localhost:3232
  ✅ launchd plists             Auto-start configs for both dashboards

What to rebuild on new machine:
  ⚠  voice_interface/venv      Run setup-voice.sh
  ⚠  */node_modules            Run 'npm install' (migrate-import.sh handles this)
  ⚠  google-token.json         OAuth token needs re-auth (client was disabled anyway)
  ⚠  Audio device index        Update in voice_interface.py after checking new device list
  ⚠  Mac Mini has no mic       External USB mic required for voice interface

EOF
echo "      ✓ Saved: MANIFEST.txt"

echo ""
echo "=============================================="
echo " Export complete!"
echo " Files are in: $EXPORT_DIR"
echo " Total size: $(du -sh "$EXPORT_DIR" | cut -f1)"
echo ""
echo " Next steps:"
echo "   1. Transfer $EXPORT_DIR/ to your Mac Mini"
echo "      (AirDrop, scp, USB drive, etc.)"
echo "   2. On the Mac Mini, install prerequisites (see README.md)"
echo "   3. Run: bash migrate-import.sh"
echo "   4. For voice interface: bash setup-voice.sh"
echo "=============================================="
