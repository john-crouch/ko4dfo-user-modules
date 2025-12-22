#!/bin/bash

#########################
# PAT-WEBVIEW QRV MODULE #
#########################
MODULE="PAT-WEBVIEW"

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

# Install the pat-webview script
sudo cp ${MODULE_DIR}/bin/pat-webview /opt/arcOS/bin/
sudo chmod +x /opt/arcOS/bin/pat-webview

# Install the desktop file
cp ${MODULE_DIR}/pat-webview.desktop $HOME/.local/share/applications/

# Remove old ICE webapp desktop file
rm -f $HOME/.local/share/applications/webapp-WinlinkClient*.desktop

# Update desktop database
update-desktop-database $HOME/.local/share/applications/ 2>/dev/null

} # END OF MODULE COMMANDS FUNCTION

# Execute the module commands, and notify the user upon failure
module_commands > $LOGFILE 2>&1 || notify-send --icon=error "$MODULE" "$MODULE module failed!"
