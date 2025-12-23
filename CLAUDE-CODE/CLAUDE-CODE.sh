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

    # Persistent storage paths (zstd tarballs on exFAT - faster extraction than gzip)
    SAVED_DIR=$ARCOS_DATA/QRV/$MYCALL/SAVED
    NODEJS_TAR=$SAVED_DIR/nodejs.tar.zst
    NPM_GLOBAL_TAR=$SAVED_DIR/node_modules_global.tar.zst

    # Check if persistent storage exists; if not, run setup script
    if [ ! -f "$NPM_GLOBAL_TAR" ]; then
        echo "Persistent storage not found, running setup script..."
        ${MODULE_DIR}/bin/setup-nodejs.sh
    fi

    # Extract /usr/share/nodejs from tarball if npm doesn't work
    if ! npm --version &> /dev/null; then
        if [ -f "$NODEJS_TAR" ]; then
            echo "Extracting nodejs modules from cache..."
            sudo rm -rf /usr/share/nodejs
            sudo tar --zstd -xf $NODEJS_TAR -C /usr/share
        fi
    fi

    # Extract /usr/local/lib/node_modules from tarball if Claude not installed
    if [ ! -d /usr/local/lib/node_modules/@anthropic-ai/claude-code ]; then
        if [ -f "$NPM_GLOBAL_TAR" ]; then
            echo "Extracting global npm modules from cache..."
            sudo mkdir -p /usr/local/lib
            sudo tar --zstd -xf $NPM_GLOBAL_TAR -C /usr/local/lib
        fi
    fi

    # Recreate claude binary symlink if needed
    if [ -d /usr/local/lib/node_modules/@anthropic-ai/claude-code ] && [ ! -L /usr/local/bin/claude ]; then
        echo "Recreating claude command symlink..."
        sudo ln -s ../lib/node_modules/@anthropic-ai/claude-code/cli.js /usr/local/bin/claude
    fi

    # Verify installation
    if command -v claude &> /dev/null; then
        INSTALLED_VERSION=$(claude --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
        echo "Claude Code ready: v${INSTALLED_VERSION}"
    else
        echo "Error: Claude Code not available"
        exit 1
    fi

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

    # Install update script
    sudo cp ${MODULE_DIR}/bin/update-claude-code /opt/arcOS/bin/
    sudo chmod +x /opt/arcOS/bin/update-claude-code

    # Install desktop file
    cp ${MODULE_DIR}/update-claude-code.desktop ~/.local/share/applications/

} # END OF MODULE COMMANDS FUNCTION

# Execute the module commands, and notify the user upon failure
module_commands > $LOGFILE 2>&1 || notify-send --icon=error "$MODULE" "$MODULE module failed!"
