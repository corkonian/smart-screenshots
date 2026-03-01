#!/bin/bash
# install-launchagent.sh
# Sets up the screenshot auto-renamer to run every hour on login.
# Run once: bash ~/Desktop/Screenshots/install-launchagent.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_SRC="$SCRIPT_DIR/com.eoin.screenshot-renamer.plist"
AGENT_DIR="$HOME/Library/LaunchAgents"
PLIST_DST="$AGENT_DIR/com.eoin.screenshot-renamer.plist"
KEY_FILE="$SCRIPT_DIR/.anthropic-api-key"
PYTHON_SCRIPT="$SCRIPT_DIR/auto-rename-screenshots.py"

echo ""
echo "🖼  Screenshot Auto-Renamer — Setup"
echo "────────────────────────────────────────"

# ── 1. Find best available Python ──
# Prefer Homebrew Python (M-series Macs), then pyenv, then system fallback
find_python() {
    for candidate in \
        /opt/homebrew/bin/python3 \
        /usr/local/bin/python3 \
        "$HOME/.pyenv/shims/python3" \
        "$(command -v python3 2>/dev/null)"; do
        if [ -x "$candidate" ] && "$candidate" -c "import sys; assert sys.version_info >= (3,8)" &>/dev/null; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

PYTHON=$(find_python) || {
    echo "✗  No suitable Python 3.8+ found."
    echo "   Install Homebrew Python: brew install python"
    exit 1
}
PY_VERSION=$("$PYTHON" --version 2>&1 | awk '{print $2}')
echo "✓  Python $PY_VERSION  ($PYTHON)"

# ── 2. Create a virtual environment and install anthropic into it ──
VENV_DIR="$SCRIPT_DIR/.venv"
VENV_PYTHON="$VENV_DIR/bin/python3"

if [ -f "$VENV_PYTHON" ] && "$VENV_PYTHON" -c "import anthropic" &>/dev/null; then
    echo "✓  Virtual environment already set up"
else
    echo "→  Creating virtual environment at $VENV_DIR ..."
    "$PYTHON" -m venv "$VENV_DIR"
    echo "→  Installing anthropic into virtual environment..."
    "$VENV_DIR/bin/pip" install anthropic --quiet
    echo "✓  anthropic installed"
fi

# Use the venv Python from here on
PYTHON="$VENV_PYTHON"

# ── 3. API key ──
if [ -n "$ANTHROPIC_API_KEY" ]; then
    echo "✓  ANTHROPIC_API_KEY found in environment"
elif [ -f "$KEY_FILE" ] && [ -s "$KEY_FILE" ]; then
    echo "✓  API key found at $KEY_FILE"
else
    echo ""
    echo "  You need an Anthropic API key."
    echo "  Get one at: https://console.anthropic.com/keys"
    echo ""
    read -rp "  Paste your API key (sk-ant-...): " INPUT_KEY
    if [[ "$INPUT_KEY" == sk-ant-* ]]; then
        echo "$INPUT_KEY" > "$KEY_FILE"
        chmod 600 "$KEY_FILE"
        echo "✓  API key saved to $KEY_FILE"
    else
        echo "✗  That doesn't look like a valid API key (should start with sk-ant-)"
        exit 1
    fi
fi

# ── 4. Build plist with correct Python path and script path ──
sed \
    -e "s|/usr/bin/python3|$PYTHON|g" \
    -e "s|/Users/eoinlooney/Desktop/Screenshots/auto-rename-screenshots.py|$PYTHON_SCRIPT|g" \
    "$PLIST_SRC" > /tmp/screenshot-renamer.plist

# ── 5. Install LaunchAgent ──
mkdir -p "$AGENT_DIR"
cp /tmp/screenshot-renamer.plist "$PLIST_DST"
rm /tmp/screenshot-renamer.plist

# Unload if already loaded (ignore errors)
launchctl unload "$PLIST_DST" 2>/dev/null || true
launchctl load -w "$PLIST_DST"
echo "✓  LaunchAgent installed — runs every hour, starting now"

# ── 6. Test run ──
echo ""
echo "→  Running a first pass now..."
"$PYTHON" "$PYTHON_SCRIPT"

echo ""
echo "────────────────────────────────────────"
echo "✅  All done! From now on:"
echo "    • New screenshots go to ~/Desktop/Screenshots automatically"
echo "      (set this in Cmd+Shift+5 → Options → Save to: Screenshots)"
echo "    • Every hour, new ones are renamed using Claude Vision AI"
echo ""
echo "    Logs:      $SCRIPT_DIR/.rename-log.txt"
echo "    Uninstall: launchctl unload $PLIST_DST && rm $PLIST_DST"
echo ""
