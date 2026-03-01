#!/usr/bin/env python3
"""
auto-rename-screenshots.py
--------------------------
Watches ~/Desktop/Screenshots for new macOS screenshots and renames them
using the Claude Vision API to generate descriptive titles.

Naming format: YYYY-MM-DD_descriptive-title.png

SETUP:
  1. pip install anthropic
  2. Save your Anthropic API key to:
       ~/Desktop/Screenshots/.anthropic-api-key
     (one line, just the key — get one at console.anthropic.com/keys)
  3. Run manually:  python3 auto-rename-screenshots.py
  4. For automatic runs, install the LaunchAgent:
       bash ~/Desktop/Screenshots/install-launchagent.sh
"""

import os
import re
import sys
import base64
import logging
from pathlib import Path

# ── Configuration ────────────────────────────────────────────────────────────
SCREENSHOTS_DIR = Path.home() / "Desktop" / "Screenshots"
LOG_FILE        = SCREENSHOTS_DIR / ".rename-log.txt"
API_KEY_FILE    = SCREENSHOTS_DIR / ".anthropic-api-key"
MODEL           = "claude-opus-4-5-20251101"

# macOS inserts a Unicode narrow no-break space (U+202F) before AM/PM
NBSP = "\u202f"

# Matches unprocessed macOS screenshot filenames
SCREENSHOT_RE = re.compile(
    r"^Screenshot (\d{4}-\d{2}-\d{2}) at [\d:.]+(?:" + NBSP + r"|[\s])?(AM|PM)?\.png$",
    re.IGNORECASE,
)
RECORDING_RE = re.compile(
    r"^Screen Recording (\d{4}-\d{2}-\d{2}) at [\d:.]+(?:" + NBSP + r"|[\s])?(AM|PM)?\.mov$",
    re.IGNORECASE,
)

# Already-processed files start with YYYY-MM-DD_
PROCESSED_RE = re.compile(r"^\d{4}-\d{2}-\d{2}_")

# ── Helpers ───────────────────────────────────────────────────────────────────

def setup_logging():
    logging.basicConfig(
        filename=LOG_FILE,
        level=logging.INFO,
        format="%(asctime)s  %(levelname)-8s  %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    # Also log to stdout so cron/LaunchAgent output is visible
    logging.getLogger().addHandler(logging.StreamHandler(sys.stdout))
    return logging.getLogger(__name__)


def get_api_key():
    key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    if key:
        return key
    if API_KEY_FILE.exists():
        return API_KEY_FILE.read_text().strip()
    return None


def extract_date(filename: str) -> str | None:
    """Return 'YYYY-MM-DD' from a macOS screenshot/recording filename, or None."""
    m = SCREENSHOT_RE.match(filename) or RECORDING_RE.match(filename)
    return m.group(1) if m else None


def ai_describe(filepath: Path, client) -> str | None:
    """Call Claude Vision API and return a kebab-case description, or None on error."""
    try:
        with open(filepath, "rb") as fh:
            b64 = base64.standard_b64encode(fh.read()).decode()

        resp = client.messages.create(
            model=MODEL,
            max_tokens=60,
            messages=[{
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {"type": "base64", "media_type": "image/png", "data": b64},
                    },
                    {
                        "type": "text",
                        "text": (
                            "Describe this screenshot in 3-6 words as a kebab-case filename "
                            "(lowercase, hyphens only, no extension, no date prefix). "
                            "Prioritise the app name and main action or content visible. "
                            "Examples: 'xcode-build-errors', 'slack-dm-thread', "
                            "'safari-apple-homepage', 'zoom-meeting-attendees'. "
                            "Reply with ONLY the kebab-case slug — nothing else."
                        ),
                    },
                ],
            }],
        )
        raw = resp.content[0].text.strip().lower()
        slug = re.sub(r"[^a-z0-9-]", "-", raw)
        slug = re.sub(r"-+", "-", slug).strip("-")
        return slug or None
    except Exception as exc:
        return None


def unique_path(directory: Path, stem: str, suffix: str) -> Path:
    """Return a path that doesn't already exist, appending -2, -3 … as needed."""
    candidate = directory / f"{stem}{suffix}"
    if not candidate.exists():
        return candidate
    n = 2
    while True:
        candidate = directory / f"{stem}-{n}{suffix}"
        if not candidate.exists():
            return candidate
        n += 1


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> int:
    log = setup_logging()

    # ── API key check ──
    api_key = get_api_key()
    if not api_key:
        log.error(
            "No Anthropic API key found.\n"
            "  Option A: export ANTHROPIC_API_KEY=sk-ant-...\n"
            f"  Option B: save the key to {API_KEY_FILE}"
        )
        return 1

    try:
        import anthropic
        client = anthropic.Anthropic(api_key=api_key)
    except ImportError:
        log.error("anthropic package not installed. Run: pip3 install anthropic")
        return 1

    if not SCREENSHOTS_DIR.exists():
        log.error(f"Screenshots folder not found: {SCREENSHOTS_DIR}")
        return 1

    renamed = failed = 0

    for filepath in sorted(SCREENSHOTS_DIR.iterdir()):
        if not filepath.is_file():
            continue
        name = filepath.name

        # Skip hidden files and already-processed files
        if name.startswith(".") or PROCESSED_RE.match(name):
            continue

        date_str = extract_date(name)
        if not date_str:
            continue  # Not a macOS screenshot we recognise

        ext = filepath.suffix.lower()

        if ext == ".png":
            slug = ai_describe(filepath, client)
            if slug:
                new_stem = f"{date_str}_{slug}"
            else:
                new_stem = f"{date_str}_screenshot"
                log.warning(f"Vision API returned nothing for '{name}'; using date-only name")
        else:
            # .mov — vision not supported; use a clean descriptive name
            new_stem = f"{date_str}_screen-recording"

        dest = unique_path(SCREENSHOTS_DIR, new_stem, ext)
        try:
            filepath.rename(dest)
            log.info(f"✓  {name}  →  {dest.name}")
            renamed += 1
        except OSError as exc:
            log.error(f"✗  Could not rename '{name}': {exc}")
            failed += 1

    if renamed or failed:
        log.info(f"Done — {renamed} renamed, {failed} failed")
    else:
        log.info("No new screenshots to rename")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
