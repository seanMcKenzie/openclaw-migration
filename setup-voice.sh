#!/usr/bin/env bash
# =============================================================================
# setup-voice.sh
# Run this on the MAC MINI after migrate-import.sh to rebuild the voice
# interface Python venv and verify audio devices.
# =============================================================================

set -euo pipefail

VOICE_DIR="$HOME/.openclaw/workspace/voice_interface"

echo "=============================================="
echo " Voice Interface Setup"
echo " $(date)"
echo "=============================================="
echo ""

# --- Check voice interface directory ---
if [ ! -d "$VOICE_DIR" ]; then
  echo "ERROR: $VOICE_DIR not found."
  echo "  Run migrate-import.sh first, then retry."
  exit 1
fi

cd "$VOICE_DIR"

# --- Check for existing requirements ---
if [ ! -f "requirements.txt" ]; then
  echo "  No requirements.txt found — generating from known dependencies..."
  cat > requirements.txt << 'EOF'
openai
discord.py
pyaudio
pynput
python-dotenv
requests
EOF
  echo "  ✓ requirements.txt created"
fi

# --- Rebuild venv ---
echo "[1/4] Creating Python virtual environment..."
if [ -d "venv" ]; then
  echo "      Existing venv found — removing it..."
  rm -rf venv
fi
python3 -m venv venv
echo "      ✓ venv created"

echo "[2/4] Installing Python dependencies..."
source venv/bin/activate
pip install --upgrade pip --quiet

# portaudio must be installed before PyAudio
if brew list portaudio &>/dev/null 2>&1; then
  echo "      portaudio found via brew ✓"
else
  echo "      Installing portaudio..."
  brew install portaudio
fi

pip install -r requirements.txt
echo "      ✓ Dependencies installed"

# --- List audio devices ---
echo "[3/4] Scanning audio devices..."
echo ""
echo "  Available audio devices:"
echo "  -------------------------------------------------------"
python3 - << 'PYEOF'
import pyaudio
p = pyaudio.PyAudio()
for i in range(p.get_device_count()):
    d = p.get_device_info_by_index(i)
    if d['maxInputChannels'] > 0:
        marker = "  [INPUT]"
    elif d['maxOutputChannels'] > 0:
        marker = "  [OUTPUT]"
    else:
        marker = "  [OTHER]"
    print(f"  Index {i:2d}{marker} {d['name']}")
p.terminate()
PYEOF
echo "  -------------------------------------------------------"
echo ""

# --- Reminder to update device index ---
echo "[4/4] Action required:"
echo ""
echo "  Your Mac Mini's audio device indices WILL differ from your old Mac."
echo "  Open voice_interface.py and update the input device index to match"
echo "  your external USB mic from the list above."
echo ""
echo "  Look for something like:"
echo "    DEVICE_INDEX = 0   # or whatever the mic shows as"
echo ""
echo "  If no mic is listed under [INPUT], your USB mic isn't connected yet."
echo "  Plug it in and re-run this script."

echo ""
echo "=============================================="
echo " Voice interface ready!"
echo ""
echo " To launch:"
echo "   cd $VOICE_DIR"
echo "   source venv/bin/activate"
echo "   set -a && source ~/.openclaw/.env && set +a"
echo "   python voice_interface.py"
echo "=============================================="
