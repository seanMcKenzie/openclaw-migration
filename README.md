# openclaw-migration

Scripts to migrate an OpenClaw multi-agent setup (K2S0 dev team) to a new Mac.

## What gets migrated

| What | How |
|---|---|
| OpenClaw config (`~/.openclaw/openclaw.json`) | Archived in `openclaw-config-*.tar.gz` |
| API keys and env vars (`~/.openclaw/.env`) | Same archive |
| All agent workspaces (`workspace-{developer,pm,qa,devops,research,designer}/`) | Same archive |
| Agent memory files (`MEMORY.md`, `memory/*.md`) | Same archive |
| Google credentials (`google-credentials.json`) | Same archive |
| Agent dashboard (`~/agent-dashboard/`) | Separate archive |
| Voice interface script (`voice_interface.py`) | Separate archive (venv excluded) |

## What needs to be rebuilt on the new machine

- Python `venv` (machine-specific — use `setup-voice.sh`)
- `node_modules` in `agent-dashboard/` (handled by `migrate-import.sh`)
- Google OAuth token may need refresh (if expired or if OAuth client was recreated)
- Audio device index in `voice_interface.py` (device list differs per machine)

## Mac Mini hardware note

The Mac Mini has **no built-in microphone**. You need an external USB mic (or audio interface) for the voice interface to work. Recommendations:
- Budget: any USB headset or USB webcam mic
- Mid: Blue Yeti, Logitech Yeti X
- Pro: Focusrite Scarlett 2i2 + XLR mic

---

## Usage

### Step 1 — Export (on your current Mac)

```bash
bash migrate-export.sh
```

Archives are saved to `~/openclaw-export/`. Transfer that folder to the Mac Mini.

---

### Step 2 — Install prerequisites on the Mac Mini

Before running the import script, you need:

**Homebrew**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**nvm + Node.js**
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
source ~/.zshrc
nvm install 22.22.0
nvm use 22.22.0
nvm alias default 22.22.0
```

**Git** (if not already installed)
```bash
xcode-select --install
```

---

### Step 3 — Import (on the Mac Mini)

Place the export archives and these scripts in the same directory, then:

```bash
bash migrate-import.sh
```

This will:
- Restore `~/.openclaw/`
- Restore `~/agent-dashboard/` and run `npm install`
- Install `sox`, `portaudio`, `mmdc` via Homebrew/npm
- Install OpenClaw globally

---

### Step 4 — Rebuild voice interface

```bash
bash setup-voice.sh
```

This will:
- Create a fresh Python venv
- Install all Python dependencies
- List all audio devices so you can identify your USB mic index
- Remind you to update `voice_interface.py` with the correct device index

---

### Step 5 — Start OpenClaw

```bash
openclaw gateway start
openclaw status
```

---

### Optional — Run OpenClaw as a persistent background service

So it survives reboots without manual intervention:

```bash
# Create launchd plist
cat > ~/Library/LaunchAgents/ai.openclaw.gateway.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>ai.openclaw.gateway</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-l</string>
    <string>-c</string>
    <string>openclaw gateway start</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/openclaw.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/openclaw.err</string>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist
```

---

## Troubleshooting

**Google Drive OAuth fails after migration**
The OAuth token is tied to a browser session. Re-auth:
```bash
# Delete stale token first
rm ~/.openclaw/google-token.json
# Re-run auth flow (opens browser)
python3 ~/.openclaw/workspace/auth_gdrive.py
```

**Voice interface can't find mic**
Run `setup-voice.sh` again after plugging in your USB mic. Update `DEVICE_INDEX` in `voice_interface.py`.

**Discord bots not connecting**
Bot tokens in `openclaw.json` are machine-independent — they should just work. Check `openclaw status` for connection errors.

**Agent dashboard not loading**
```bash
cd ~/agent-dashboard
npm install
node server.js
```
Dashboard runs on port 3131 by default.
