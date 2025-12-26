#!/bin/bash

########################
#  VARAC QRV MODULE    #
########################
MODULE="VARAC"

# STATION INFO
source $HOME/.station-info

# PATHS
ARCOS_DATA=/arcHIVE
MODULE_DIR=$ARCOS_DATA/QRV/$MYCALL/arcos-linux-modules/USER/ko4dfo-user-modules/$MODULE
LOGFILE=$MODULE_DIR/$MODULE.log
SAVE_DIR=$ARCOS_DATA/QRV/$MYCALL/SAVED/$MODULE
VARA_SAVE_DIR=$ARCOS_DATA/QRV/$MYCALL/SAVED/VARA
########################

### MODULE COMMANDS FUNCTION ###
module_commands () {

export WINEARCH=win32
export WINEPREFIX=$HOME/.wine_vara_32

# Configuration files that VarAC stores in home directory
CONFIG_FILES="VarAC.ini VarAC_cat_commands.ini VarAC_frequencies.conf VarAC_frequency_schedule.conf VarAC_alert_tags.conf"

### CHECK VARA DEPENDENCY ###
# VARA module (20_VARA.sh) must run before VARAC to set up Wine prefix
check_vara () {
    echo "=== Checking VARA dependency ==="

    if [ ! -d "$WINEPREFIX/drive_c/VARA" ]; then
        echo "ERROR: VARA not installed in Wine prefix"
        notify-send --icon=error "$MODULE" "VARA module must run first. Enable 20_VARA.sh in ENABLED_MODULES before VARAC.sh."
        return 1
    fi

    echo "VARA dependency check passed"
    return 0
}

### INSTALL VARAC ###
install_varac () {
    echo "=== Installing VarAC ==="

    # Extract VarAC to Wine prefix
    VARAC_DIR="$WINEPREFIX/drive_c/VarAC"
    mkdir -p "$VARAC_DIR"

    unzip -o -q "$MODULE_DIR/VarAC_v13.0.1.zip" -d "$VARAC_DIR"

    if [ ! -f "$VARAC_DIR/VarAC.exe" ]; then
        echo "ERROR: VarAC.exe not found after extraction"
        return 1
    fi

    echo "VarAC installed to $VARAC_DIR"
}

### CONFIGURE VARAC ###
configure_varac () {
    echo "=== Configuring VarAC ==="

    # Copy template config and substitute callsign and grid square
    if [ -f "$MODULE_DIR/config/VarAC.ini.template" ]; then
        cp "$MODULE_DIR/config/VarAC.ini.template" "$HOME/VarAC.ini"
        sed -i "s/XXXMYCALLXXX/$MYCALL/g" "$HOME/VarAC.ini"
        sed -i "s/XXXMYLOCXXX/$MYLOC/g" "$HOME/VarAC.ini"
    fi

    # Copy default cat commands if template exists
    if [ -f "$MODULE_DIR/config/VarAC_cat_commands.ini" ]; then
        cp "$MODULE_DIR/config/VarAC_cat_commands.ini" "$HOME/"
    elif [ -f "$WINEPREFIX/drive_c/VarAC/VarAC_cat_commands.ini" ]; then
        # Use the one from the distribution
        cp "$WINEPREFIX/drive_c/VarAC/VarAC_cat_commands.ini" "$HOME/"
    fi

    # Create empty config files if they don't exist
    touch "$HOME/VarAC_frequencies.conf"
    touch "$HOME/VarAC_frequency_schedule.conf"
    touch "$HOME/VarAC_alert_tags.conf"

    echo "VarAC configured for $MYCALL"
}

### PERSIST VARAC ###
persist_varac () {
    echo "=== Persisting VarAC configuration ==="

    mkdir -p "$SAVE_DIR"

    # Save all config files
    for cfg in $CONFIG_FILES; do
        if [ -f "$HOME/$cfg" ]; then
            cp "$HOME/$cfg" "$SAVE_DIR/"
        fi
    done

    # Update VARA tarball to include VarAC
    # This ensures VarAC.exe persists with the Wine prefix
    echo "Updating VARA tarball with VarAC..."
    tar -C $HOME -rf "$VARA_SAVE_DIR/wine_vara.tar" .wine_vara_32/drive_c/VarAC

    echo "VarAC configuration persisted"
}

### RESTORE VARAC ###
restore_varac () {
    echo "=== Restoring VarAC configuration ==="

    # Restore config files from persistent storage
    for cfg in $CONFIG_FILES; do
        if [ -f "$SAVE_DIR/$cfg" ]; then
            cp "$SAVE_DIR/$cfg" "$HOME/"
            echo "Restored $cfg"
        fi
    done

    # Verify VarAC.exe exists (should be in restored VARA tarball)
    if [ ! -f "$WINEPREFIX/drive_c/VarAC/VarAC.exe" ]; then
        echo "VarAC.exe missing, re-extracting..."
        install_varac
    fi

    echo "VarAC configuration restored"
}

### INSTALL LAUNCHER ###
install_launcher () {
    echo "=== Installing VarAC launcher ==="

    # Install launcher script
    sudo mkdir -p /opt/arcOS/bin
    sudo cp "$MODULE_DIR/bin/varac-launch" /opt/arcOS/bin/
    sudo chmod +x /opt/arcOS/bin/varac-launch

    # Install desktop file
    mkdir -p "$HOME/.local/share/applications"
    cp "$MODULE_DIR/applications/VarAC.desktop" "$HOME/.local/share/applications/"

    # Install icons in multiple sizes
    mkdir -p "$HOME/.local/share/icons/hicolor/48x48/apps"
    mkdir -p "$HOME/.local/share/icons/hicolor/32x32/apps"
    mkdir -p "$HOME/.local/share/icons/hicolor/96x96/apps"
    mkdir -p "$HOME/.local/share/icons"

    if [ -f "$MODULE_DIR/icons/varac-48.png" ]; then
        cp "$MODULE_DIR/icons/varac-48.png" "$HOME/.local/share/icons/hicolor/48x48/apps/varac.png"
        cp "$MODULE_DIR/icons/varac-32.png" "$HOME/.local/share/icons/hicolor/32x32/apps/varac.png"
        cp "$MODULE_DIR/icons/varac-100.png" "$HOME/.local/share/icons/hicolor/96x96/apps/varac.png"
        cp "$MODULE_DIR/icons/varac-100.png" "$HOME/.local/share/icons/varac.png"
    fi

    # Update icon cache
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

    echo "VarAC launcher installed"
}

### MAIN DEPLOYMENT LOGIC ###
deploy_varac () {
    # Check VARA dependency first
    if ! check_vara; then
        return 1
    fi

    # Check if this is first run or subsequent boot
    if [ -f "$SAVE_DIR/VarAC.ini" ]; then
        # Subsequent boot - restore from persistent storage
        echo "=== VarAC subsequent boot ==="
        restore_varac
    else
        # First run - full installation
        echo "=== VarAC first run installation ==="
        install_varac
        configure_varac
        persist_varac

        notify-send --icon=info "$MODULE" "VarAC installed! Find it in the Applications menu.\n\nRemember to enable 'Linux Compatible Mode' in Settings if you see display issues."
    fi

    # Always install launcher (overlay wipes /opt each reboot)
    install_launcher

    echo "=== VarAC deployment complete ==="
}

# Run deployment
deploy_varac

} # END OF MODULE COMMANDS FUNCTION

# Execute the module commands, and notify the user upon failure
module_commands > $LOGFILE 2>&1 || notify-send --icon=error "$MODULE" "$MODULE module failed!"
