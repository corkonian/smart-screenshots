#!/bin/bash
# build.sh — builds SmartScreenshots.pkg
# Run from Terminal: bash ~/Desktop/Screenshots/pkg-builder/build.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
PAYLOAD_DIR="$SCRIPT_DIR/payload"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
RESOURCES_DIR="$SCRIPT_DIR/resources"
COMPONENT_PKG="$BUILD_DIR/SmartScreenshots-component.pkg"
FINAL_PKG="$SCRIPT_DIR/../SmartScreenshots.pkg"

echo ""
echo "📦  Building SmartScreenshots.pkg"
echo "────────────────────────────────────────"

# ── Check for required build tools ──────────────────────────────────────────
if ! command -v pkgbuild &>/dev/null; then
    echo "✗  pkgbuild not found."
    echo "   Install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi
if ! command -v productbuild &>/dev/null; then
    echo "✗  productbuild not found."
    echo "   Install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi

# ── Prepare ──────────────────────────────────────────────────────────────────
mkdir -p "$BUILD_DIR"
rm -f "$COMPONENT_PKG" "$FINAL_PKG"

# Make scripts executable
chmod +x "$SCRIPTS_DIR/postinstall"

# ── Step 1: Build the component package (payload + scripts) ──────────────────
echo "→  Building component package..."
pkgbuild \
    --root "$PAYLOAD_DIR" \
    --scripts "$SCRIPTS_DIR" \
    --identifier "com.smartscreenshots" \
    --version "1.0" \
    --install-location "/" \
    "$COMPONENT_PKG"
echo "✓  Component package built"

# ── Step 2: Build the product archive (adds installer UI) ────────────────────
echo "→  Building product archive..."
productbuild \
    --distribution "$SCRIPT_DIR/Distribution.xml" \
    --resources "$RESOURCES_DIR" \
    --package-path "$BUILD_DIR" \
    "$FINAL_PKG"
echo "✓  Product archive built"

echo ""
echo "────────────────────────────────────────"
echo "✅  Done!  →  $(basename "$FINAL_PKG")"
echo ""
echo "   To install:  double-click SmartScreenshots.pkg"
echo "   To share:    send the .pkg file to any Mac"
echo ""
