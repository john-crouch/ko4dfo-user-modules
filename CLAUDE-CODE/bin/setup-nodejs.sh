#!/bin/bash

###########################################
# NODEJS + CLAUDE CODE SETUP/CACHE SCRIPT #
###########################################
# Downloads, installs, and caches nodejs, npm, and Claude Code
# to persistent storage for use on Live systems.
#
# Run this script once to populate persistent storage.
# The main CLAUDE-CODE module will extract from cache on boot.

set -e

# STATION INFO
source $HOME/.station-info

# PATHS
ARCOS_DATA=/arcHIVE
SAVED_DIR=$ARCOS_DATA/QRV/$MYCALL/SAVED
NODEJS_TAR=$SAVED_DIR/nodejs.tar.gz
NPM_GLOBAL_TAR=$SAVED_DIR/node_modules_global.tar.gz
MODULE_DIR=$ARCOS_DATA/QRV/$MYCALL/arcos-linux-modules/USER/ko4dfo-user-modules/CLAUDE-CODE

echo "=== NodeJS + Claude Code Setup Script ==="
echo ""

# Step 1: Install nodejs and npm with all dependencies
echo "[1/4] Installing nodejs and npm..."
sudo apt-get update
sudo apt-get install -y nodejs npm

# Verify npm works
if ! npm --version &> /dev/null; then
    echo "ERROR: npm installation failed"
    exit 1
fi
echo "  npm $(npm --version) installed successfully"

# Step 2: Install Claude Code globally
echo "[2/4] Installing Claude Code..."
CACHE_DIR=${MODULE_DIR}/packages
mkdir -p $CACHE_DIR

# Check for cached package or download
CACHED_PKG=$(ls $CACHE_DIR/anthropic-ai-claude-code-*.tgz 2>/dev/null | head -n1)
if [ -z "$CACHED_PKG" ]; then
    echo "  Downloading Claude Code package..."
    cd $CACHE_DIR
    npm pack @anthropic-ai/claude-code
    CACHED_PKG=$(ls $CACHE_DIR/anthropic-ai-claude-code-*.tgz 2>/dev/null | head -n1)
fi

if [ -f "$CACHED_PKG" ]; then
    echo "  Installing from $CACHED_PKG..."
    sudo npm install -g "$CACHED_PKG"
else
    echo "ERROR: Failed to download Claude Code package"
    exit 1
fi

# Verify claude works
if ! claude --version &> /dev/null; then
    echo "ERROR: Claude Code installation failed"
    exit 1
fi
echo "  Claude Code $(claude --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1) installed successfully"

# Step 3: Cache /usr/share/nodejs as tarball (preserves symlinks)
echo "[3/4] Caching /usr/share/nodejs to persistent storage..."
mkdir -p $SAVED_DIR
if [ -f "$NODEJS_TAR" ]; then
    echo "  Already cached, skipping"
else
    echo "  Creating tarball (preserves symlinks)..."
    sudo tar -czf $NODEJS_TAR -C /usr/share nodejs
    NODEJS_SIZE=$(du -sh $NODEJS_TAR | cut -f1)
    echo "  Cached $NODEJS_SIZE to $NODEJS_TAR"
fi

# Step 4: Cache /usr/local/lib/node_modules as tarball
echo "[4/4] Caching /usr/local/lib/node_modules to persistent storage..."
if [ -f "$NPM_GLOBAL_TAR" ]; then
    echo "  Already cached, skipping"
else
    echo "  Creating tarball..."
    sudo tar -czf $NPM_GLOBAL_TAR -C /usr/local/lib node_modules
    NPM_SIZE=$(du -sh $NPM_GLOBAL_TAR | cut -f1)
    echo "  Cached $NPM_SIZE to $NPM_GLOBAL_TAR"
fi

echo ""
echo "=== Setup Complete ==="
echo "Persistent storage:"
echo "  nodejs:     $NODEJS_TAR"
echo "  global npm: $NPM_GLOBAL_TAR"
echo ""
echo "On next boot, CLAUDE-CODE module will extract from these tarballs."
