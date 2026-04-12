#!/bin/bash
set -euo pipefail

# OpenClaw Controller — install script
# Usage: curl -fsSL <raw-url>/install.sh | bash

APP_NAME="OpenClawController"
DISPLAY_NAME="OpenClaw Controller"
REPO_URL="${OPENCLAW_CONTROLLER_REPO:-https://github.com/YOUR_USERNAME/openclaw-controller.git}"
INSTALL_DIR="$HOME/.openclaw-controller-src"
DEST="/Applications/$APP_NAME.app"

echo ""
echo "  OpenClaw Controller — Installer"
echo "  ================================"
echo ""

# Check requirements
command -v swift >/dev/null 2>&1 || {
    echo "Error: Swift is not installed."
    echo "Run: xcode-select --install"
    exit 1
}

command -v git >/dev/null 2>&1 || {
    echo "Error: git is not installed."
    echo "Run: xcode-select --install"
    exit 1
}

# Clone or update
if [ -d "$INSTALL_DIR" ]; then
    echo "Updating existing source…"
    cd "$INSTALL_DIR"
    git pull --ff-only
else
    echo "Downloading source…"
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Build
echo ""
echo "Building (this may take ~40s on first run)…"
./build.sh

# Install
if [ -d "$DEST" ]; then
    echo ""
    echo "Replacing existing installation…"
    killall "$APP_NAME" 2>/dev/null || true
    sleep 1
    rm -rf "$DEST"
fi

echo "Installing to /Applications…"
cp -R "$APP_NAME.app" /Applications/

echo ""
echo "Done! $DISPLAY_NAME has been installed to:"
echo "  $DEST"
echo ""
echo "To launch:"
echo "  open -a $APP_NAME"
echo ""
echo "To auto-launch on login:"
echo "  System Settings → General → Login Items → + → $APP_NAME"
echo ""
echo "To update later, just re-run this script."
echo ""

open -a "$APP_NAME"
