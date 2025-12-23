#!/bin/bash

############################
# UPDATE-MODULES QRV MODULE #
############################
MODULE="UPDATE-MODULES"

# STATION INFO
source $HOME/.station-info

# PATHS
ARCOS_DATA=/arcHIVE
MODULE_DIR=$ARCOS_DATA/QRV/$MYCALL/arcos-linux-modules/USER/ko4dfo-user-modules/$MODULE
LOGFILE=$MODULE_DIR/$MODULE.log
SAVE_DIR=$ARCOS_DATA/QRV/$MYCALL/SAVED/$MODULE
############################

### MODULE COMMANDS FUNCTION ###
module_commands () {

    # Install custom update-modules script (separate from stock)
    sudo cp ${MODULE_DIR}/bin/update-modules-custom /opt/arcOS/bin/update-modules-custom
    sudo chmod +x /opt/arcOS/bin/update-modules-custom
    echo "Installed update-modules-custom script"

    # Install smart modules-status (replaces stock - only notifies for unmodified file updates)
    sudo cp ${MODULE_DIR}/bin/modules-status /opt/arcOS/bin/modules-status
    sudo chmod +x /opt/arcOS/bin/modules-status
    echo "Installed smart modules-status script"

    # Install desktop file
    cp ${MODULE_DIR}/update-modules-custom.desktop $HOME/.local/share/applications/
    echo "Installed desktop launcher"

} # END OF MODULE COMMANDS FUNCTION

# Execute the module commands, and notify the user upon failure
module_commands > $LOGFILE 2>&1 || notify-send --icon=error "$MODULE" "$MODULE module failed!"
