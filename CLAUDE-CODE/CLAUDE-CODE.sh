#!/bin/bash

###########################
# CLAUDE-CODE QRV MODULE  #
###########################
MODULE="CLAUDE-CODE"

# STATION INFO
source $HOME/.station-info

# PATHS
ARCOS_DATA=/arcHIVE
MODULE_DIR=$ARCOS_DATA/QRV/$MYCALL/arcos-linux-modules/USER/ko4dfo-user-modules/$MODULE
LOGFILE=$MODULE_DIR/$MODULE.log
SAVE_DIR=$ARCOS_DATA/QRV/$MYCALL/SAVED/$MODULE
########################

### MODULE COMMANDS FUNCTION ###
module_commands () {

    # Ensure npm and Node.js are installed
    if ! command -v npm &> /dev/null; then
        echo "npm not found, installing nodejs and npm..."
        sudo apt-get update
        sudo apt-get install -y nodejs npm
        sudo npm install -g npm@latest
    fi

    # Check if Claude Code is already installed
    if command -v claude &> /dev/null; then
        INSTALLED_VERSION=$(claude --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
        echo "Claude Code already installed: v${INSTALLED_VERSION}"
    else
        # Cache directory for packages
        CACHE_DIR=${MODULE_DIR}/packages
        mkdir -p $CACHE_DIR

        # Check if we have a cached package
        CACHED_PKG=$(ls $CACHE_DIR/anthropic-ai-claude-code-*.tgz 2>/dev/null | head -n1)

        if [ -z "$CACHED_PKG" ]; then
            # No cached package, download it
            echo "Downloading Claude Code package to cache..."
            cd $CACHE_DIR
            npm pack @anthropic-ai/claude-code
            CACHED_PKG=$(ls $CACHE_DIR/anthropic-ai-claude-code-*.tgz 2>/dev/null | head -n1)
        fi

        # Install from cached package
        if [ -f "$CACHED_PKG" ]; then
            echo "Installing Claude Code from cached package..."
            sudo npm install -g "$CACHED_PKG"
        else
            echo "Error: Failed to download/cache Claude Code package"
            exit 1
        fi
    fi

    # Install save-claude-code.sh script to /opt/arcOS/bin/
    sudo cp ${MODULE_DIR}/bin/save-claude-code.sh /opt/arcOS/bin/
    sudo chmod +x /opt/arcOS/bin/save-claude-code.sh

    # Install desktop launcher
    cp ${MODULE_DIR}/save-claude-code.desktop $HOME/.local/share/applications/
    chmod +x $HOME/.local/share/applications/save-claude-code.desktop

    # Create persistent config directory
    mkdir -p $SAVE_DIR

    # Claude Code uses ~/.claude for its config (not ~/.config/claude-code)
    # If there's existing config that isn't a symlink, migrate it
    if [ -d $HOME/.claude ] && [ ! -L $HOME/.claude ]; then
        echo "Migrating existing Claude Code config to persistent storage..."
        rsync -a $HOME/.claude/ ${SAVE_DIR}/
        rm -rf $HOME/.claude
    fi

    # Remove broken symlink if it exists
    if [ -L $HOME/.claude ] && [ ! -e $HOME/.claude ]; then
        unlink $HOME/.claude
    fi

    # Create symlink to persist config across reboots
    if [ ! -L $HOME/.claude ]; then
        ln -s ${SAVE_DIR} $HOME/.claude
        echo "Claude Code config (~/.claude) linked to persistent storage"
    fi

    # Verify installation
    if command -v claude &> /dev/null; then
        echo "Claude Code successfully installed"
        claude --version
    else
        echo "Error: Claude Code installation failed"
        exit 1
    fi

} # END OF MODULE COMMANDS FUNCTION

# Execute the module commands, and notify the user upon failure
module_commands > $LOGFILE 2>&1 || notify-send --icon=error "$MODULE" "$MODULE module failed!"
