# openclaw-migration

Scripts to migrate the full K2S0 multi-agent setup to a new Mac (Mac Mini or otherwise) without losing anything.

## What gets migrated

| What | Preserved | Notes |
|---|---|---|
| OpenClaw config (`~/.openclaw/openclaw.json`) | ✅ | Discord bot tokens, model config |
| API keys (`~/.openclaw/.env`) | ✅ | Anthropic, OpenAI, Figma, Exa, GitHub PAT |
| **All agent memories** | ✅ | MEMORY.md, memory/YYYY-MM-DD.md for all agents |
| Agent workspaces (SOUL.md, AGENTS.md, etc.) | ✅ | K2S0, Charlie, Dennis, Mac, Frank, Sweet Dee, Cricket |
| MedSales project files | ✅ | Schema, PRDs, wireframes, test plans, architecture docs |
| Google service account credentials | ✅ | google-credentials.json |
| **Agent dashboard** (port 3131) | ✅ | Code; node_modules excluded (rebuilt on import) |
| **Project dashboard + live data** (port 3232) | ✅ | Code + dashboard.db (projects, tasks, sprints) |
| **launchd auto-start plists** | ✅ | Both dashboards auto-start on login |
| Voice interface script | ✅ | voice_interface.py inside ~/.openclaw |

## What needs to be rebuilt

| What | How |
|---|---|
| Python `venv` (voice interface) | `bash setup-voice.sh` |
| `node_modules` in dashboards | Handled automatically by `migrate-import.sh` |
| Google OAuth token | Re-run `auth_gdrive.py` (OAuth client was disabled anyway) |
| Audio device index | Update in `voice_interface.py` after seeing new device list |
| External USB mic | Mac Mini has no built-in mic — required for voice interface |

---

## Usage

### Step 1 — Export (on your current Mac)

```bash
bash migrate-export.sh
```

Creates `~/openclaw-export/` with all archives. Typical size: 50–200MB depending on workspace contents.

---

### Step 2 — Install prerequisites on the Mac Mini

**Homebrew**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**nvm + Node.js v22**
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
source ~/.zshrc
nvm install 22.22.0
nvm use 22.22.0
nvm alias default 22.22.0
```

**Git** (if not installed)
```bash
xcode-select --install
```

---

### Step 3 — Transfer archives to Mac Mini

```bash
# AirDrop, or scp:
scp -r ~/openclaw-export/ macmini:~/openclaw-export/
scp migrate-import.sh setup-voice.sh macmini:~/openclaw-export/
```

---

### Step 4 — Import (on the Mac Mini)

```bash
cd ~/openclaw-export
bash migrate-import.sh
```

This will:
- Restore `~/.openclaw/` (all workspaces + memories)
- Restore `~/agent-dashboard/` + run `npm install`
- Restore `~/project-dashboard/` + live `dashboard.db` + run `npm install`
- Install `sox`, `portaudio`, `mmdc` via Homebrew/npm
- Install OpenClaw globally
- Create or restore launchd plists for both dashboards
- Load both services (auto-start on login, auto-restart on crash)
- Verify both dashboards are responding

---

### Step 5 — Start OpenClaw

```bash
openclaw gateway start
openclaw status
```

---

### Step 6 — Voice interface

```bash
bash setup-voice.sh
```

This will:
- Create a fresh Python venv in `~/.openclaw/workspace/voice_interface/`
- Install all Python dependencies (openai, discord.py, pyaudio, pynput, etc.)
- List all audio devices — find your USB mic index
- Remind you to update `voice_interface.py` with the correct device index

**To launch voice interface after setup:**
```bash
cd ~/.openclaw/workspace/voice_interface
source venv/bin/activate
set -a && source ~/.openclaw/.env && set +a
python voice_interface.py
```

**Architecture recap:**
- Mic (PTT) → Whisper STT → Discord message (as Sean, `[voice]` prefix)
- K2S0 responds in 1–2 sentences
- Background watcher speaks K2S0's reply via TTS (OpenAI `fable` voice + sox pitch shift)

---

## After migration — verify everything

```
✅ openclaw status            → K2S0 connected to Discord
✅ http://localhost:3131      → Agent Dashboard (live WebSocket updates)
✅ http://localhost:3232      → Project Dashboard (MedSales Sprint 1 data intact)
✅ python voice_interface.py  → Voice interface running
```

---

## Mac Mini hardware note

The Mac Mini has **no built-in microphone**. Voice interface won't work without one:
- Budget: USB headset, Logitech webcam mic
- Mid: Blue Yeti, Yeti Nano
- Pro: Focusrite Scarlett 2i2 + XLR mic

After plugging in the mic, re-run `setup-voice.sh` to see the updated device list.

---

## Troubleshooting

**Dashboards not loading after import**
```bash
# Check logs
cat /tmp/agent-dashboard.log
cat /tmp/project-dashboard.log

# Restart manually
launchctl kickstart -k gui/$(id -u)/ai.k2s0.agent-dashboard
launchctl kickstart -k gui/$(id -u)/ai.k2s0.project-dashboard
```

**Google Drive OAuth fails**
```bash
rm ~/.openclaw/google-token.json
python3 ~/.openclaw/workspace/auth_gdrive.py
```

**Discord bots not connecting**
Bot tokens are in `~/.openclaw/openclaw.json` — machine-independent, carry over fine. Check `openclaw status` for errors.

**Voice interface "no input device"**
Plug in USB mic first, then run `setup-voice.sh` to get updated device list.

**node_modules errors**
```bash
cd ~/agent-dashboard && npm install
cd ~/project-dashboard && npm install
```

---

## Color legend for K2S0's team

| Agent | Role | Model |
|---|---|---|
| K2S0 | Coordinator | claude-sonnet-4-6 |
| Charlie | Developer (Java/Spring Boot) | claude-opus-4-6 |
| Dennis | PM / backlog | claude-sonnet-4-6 |
| Mac | QA / testing | claude-sonnet-4-6 |
| Frank | DevOps / Solutions Architect | claude-opus-4-6 |
| Sweet Dee | Research | claude-sonnet-4-6 |
| Cricket | UI/UX design | claude-sonnet-4-6 |
