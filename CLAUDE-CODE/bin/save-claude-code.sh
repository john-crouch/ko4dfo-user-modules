#!/bin/bash

##########################
# CLAUDE-CODE QRV MODULE #
##########################
MODULE="CLAUDE-CODE"

# STATION INFO
source $HOME/.station-info

# PATHS
ARCOS_DATA=/arcHIVE
SAVE_DIR=$ARCOS_DATA/QRV/$MYCALL/SAVED/$MODULE
########################

# Check if Claude Code config exists
if [ -L $HOME/.config/claude-code ] && [ -f $HOME/.config/claude-code/config.json ]; then
    notify-send --icon=claude-code "Claude Code" "Configuration is already persistent!\n\nYour config is automatically saved to:\n$SAVE_DIR"
elif [ -f $HOME/.config/claude-code/config.json ]; then
    # Legacy: config exists but isn't symlinked, migrate it
    mkdir -p $SAVE_DIR
    rsync -a $HOME/.config/claude-code/ ${SAVE_DIR}/
    rm -rf $HOME/.config/claude-code
    ln -s ${SAVE_DIR} $HOME/.config/claude-code
    notify-send --icon=claude-code "Claude Code" "Configuration migrated to persistent storage!\n\nYour API key and settings will now persist across reboots."
else
    notify-send --icon=error "Claude Code" "No configuration found!\n\nPlease run 'claude' and use the '/login' command to configure Claude Code."
fi
