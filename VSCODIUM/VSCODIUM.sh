#!/bin/bash

########################
# VSCODIUM QRV MODULE  #
########################
MODULE="VSCODIUM"

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

    # Ensure libsecret-tools is installed (for keyring/credential storage)
    if ! command -v secret-tool &> /dev/null; then
        echo "Installing libsecret-tools for keyring support..."
        sudo apt-get install -y libsecret-tools
    fi

    # Create save directory
    mkdir -p ${SAVE_DIR}

    # If there's existing config that isn't a symlink, migrate it
    if [ -d $HOME/.config/VSCodium ] && [ ! -L $HOME/.config/VSCodium ]; then
        echo "Migrating existing VSCodium config to persistent storage..."
        rsync -a $HOME/.config/VSCodium/ ${SAVE_DIR}/
        rm -rf $HOME/.config/VSCodium
    fi

    # Remove broken symlink if it exists
    if [ -L $HOME/.config/VSCodium ] && [ ! -e $HOME/.config/VSCodium ]; then
        unlink $HOME/.config/VSCodium
    fi

    # Create symlink to persist config across reboots
    if [ ! -L $HOME/.config/VSCodium ]; then
        ln -s ${SAVE_DIR} $HOME/.config/VSCodium
    fi

    # Also persist extensions directory (~/.vscode-oss/extensions)
    EXT_SAVE_DIR=${SAVE_DIR}/extensions
    mkdir -p ${EXT_SAVE_DIR}

    # Migrate existing extensions if not a symlink
    if [ -d $HOME/.vscode-oss/extensions ] && [ ! -L $HOME/.vscode-oss/extensions ]; then
        echo "Migrating existing VSCodium extensions to persistent storage..."
        rsync -a $HOME/.vscode-oss/extensions/ ${EXT_SAVE_DIR}/
        rm -rf $HOME/.vscode-oss/extensions
    fi

    # Remove broken symlink if it exists
    if [ -L $HOME/.vscode-oss/extensions ] && [ ! -e $HOME/.vscode-oss/extensions ]; then
        unlink $HOME/.vscode-oss/extensions
    fi

    # Create extensions symlink
    mkdir -p $HOME/.vscode-oss
    if [ ! -L $HOME/.vscode-oss/extensions ]; then
        ln -s ${EXT_SAVE_DIR} $HOME/.vscode-oss/extensions
        echo "VSCodium extensions linked to persistent storage"
    fi

} # END OF MODULE COMMANDS FUNCTION

# Execute the module commands, and notify the user upon failure
module_commands > $LOGFILE 2>&1 || notify-send --icon=error "$MODULE" "$MODULE module failed!"
