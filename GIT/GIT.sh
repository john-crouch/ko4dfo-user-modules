#!/bin/bash

###########################
# GIT QRV MODULE          #
###########################
MODULE="GIT"

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

    # Create persistent storage directory
    mkdir -p $SAVE_DIR

    # Persist ~/.gitconfig
    # Can't symlink single files TO exFAT, so we copy to/from persistent storage
    GITCONFIG_BACKUP=$SAVE_DIR/gitconfig
    if [ -f "$GITCONFIG_BACKUP" ] && [ ! -f "$HOME/.gitconfig" ]; then
        # Restore from persistent storage on boot
        cp "$GITCONFIG_BACKUP" "$HOME/.gitconfig"
        echo "Restored ~/.gitconfig from persistent storage"
    elif [ -f "$HOME/.gitconfig" ]; then
        # Save current file to persistent storage (will be restored next boot)
        cp "$HOME/.gitconfig" "$GITCONFIG_BACKUP"
        echo "Saved ~/.gitconfig to persistent storage"
    fi

    # Show current git identity
    if [ -f "$HOME/.gitconfig" ]; then
        GIT_NAME=$(git config --global user.name 2>/dev/null)
        GIT_EMAIL=$(git config --global user.email 2>/dev/null)
        echo "Git identity: $GIT_NAME <$GIT_EMAIL>"
    fi

} # END OF MODULE COMMANDS FUNCTION

# Execute the module commands, and notify the user upon failure
module_commands > $LOGFILE 2>&1 || notify-send --icon=error "$MODULE" "$MODULE module failed!"
