# SmartScreenshots

AI-powered macOS screenshot auto-renamer. Instead of `Screenshot 2026-02-17 at 1.05.48 PM.png` you get `2026-02-17_zoom-weekly-team-standup.png` — automatically.

## How it works

1. macOS saves screenshots to `~/Desktop/Screenshots`
2. Every hour a background LaunchAgent runs `auto-rename-screenshots.py`
3. Each unprocessed screenshot is sent to the **Claude Vision API**
4. Claude generates a short descriptive slug → the file is renamed to `YYYY-MM-DD_descriptive-title.png`

## Quick install (manual)

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/smart-screenshots.git ~/Desktop/Screenshots

# 2. Run the setup script
bash ~/Desktop/Screenshots/install-launchagent.sh
```

The script will:
- Find the best available Python 3
- Create a `.venv` and install the `anthropic` SDK
- Prompt for your Anthropic API key
- Install and start the LaunchAgent

## Installer (.pkg)

For a friendlier install experience, build the macOS package:

```bash
bash ~/Desktop/Screenshots/pkg-builder/build.sh
```

Then double-click `SmartScreenshots.pkg` — it walks through the setup with a native macOS installer UI.

## Getting an API key

1. Go to [console.anthropic.com/keys](https://console.anthropic.com/keys) and sign in
2. Click **Create Key**, name it "SmartScreenshots"
3. Copy the key (starts with `sk-ant-`)
4. Save it to `~/Desktop/Screenshots/.anthropic-api-key` (one line, no quotes)

## Cost

Claude's API charges per image analysed. At current rates, renaming 100 screenshots costs roughly **$0.01–$0.05**. Set a spending limit at [console.anthropic.com/settings/limits](https://console.anthropic.com/settings/limits).

## Files

| File | Purpose |
|------|---------|
| `auto-rename-screenshots.py` | Main rename script |
| `install-launchagent.sh` | One-time setup script |
| `com.corkcode.smartscreenshots.plist` | LaunchAgent plist template |
| `pkg-builder/` | macOS `.pkg` installer source |

## Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/com.corkcode.smartscreenshots.plist
rm ~/Library/LaunchAgents/com.corkcode.smartscreenshots.plist
```
