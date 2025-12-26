#!/bin/bash

######################
# VARA QRV MODULE    #
######################
MODULE="VARA"

# STATION INFO
source "$HOME/.station-info"

# PATHS
ARCOS_DATA=/arcHIVE
MODULE_DIR="$ARCOS_DATA/QRV/$MYCALL/arcos-linux-modules/USER/ko4dfo-user-modules/$MODULE"
LOGFILE="$MODULE_DIR/$MODULE.log"
SAVE_DIR="$ARCOS_DATA/QRV/$MYCALL/SAVED/$MODULE"
########################

### MODULE COMMANDS FUNCTION ###
module_commands () {

export WINEARCH=win32
export WINEPREFIX="$HOME/.wine_vara_32"

prepare_vara () {
    echo "[VARA] Initializing Wine prefix..."

    # Create fresh 32-bit Wine prefix (keeps Wine Mono)
    wineboot --init
    wineserver -w

    # Cache and install VB6 runtime
    mkdir -p "$HOME/.cache/winetricks/vb6run"
    cp "$MODULE_DIR/exe/VB6.0-KB290887-X86.exe" "$HOME/.cache/winetricks/vb6run/"
    winetricks -q vb6run

    # Cache and install VC++ 2015 runtime
    mkdir -p "$HOME/.cache/winetricks/vcrun2015"
    cp "$MODULE_DIR/exe/vc_redist.x86.exe" "$HOME/.cache/winetricks/vcrun2015/"
    winetricks -q vcrun2015

    # Copy pdh.dll
    cp "$MODULE_DIR/dll/pdh.dll" "$WINEPREFIX/drive_c/windows/system32/"

    # Install MDAC 2.8 for msdatsrc.tlb (required for VARA TCP port 8300)
    # This properly registers the type library that VARA needs for socket communication
    winetricks -q mdac28

    # Configure COM port and ALSA audio for DigiRig
    wine reg add "HKLM\\Software\\Wine\\Ports" /v COM1 /d /dev/digirig /t REG_SZ /f
    wine reg add "HKCU\\Software\\Wine\\Drivers\\winealsa.drv" /v ALSAInputDevices /d digirig-rx /t REG_MULTI_SZ /f
    wine reg add "HKCU\\Software\\Wine\\Drivers\\winealsa.drv" /v ALSAOutputDevices /d digirig-tx /t REG_MULTI_SZ /f

    # Set Windows 10 mode for better .NET compatibility
    wine reg add "HKCU\\Software\\Wine" /v Version /t REG_SZ /d win10 /f

    wineserver -w
    echo "[VARA] Wine prefix prepared"
}

install_vara () {
    echo "[VARA] Installing VARA HF..."
    unzip -o -d /tmp "$MODULE_DIR/exe/VARA HF v4.8.9 setup.zip"
    wine /tmp/"VARA setup (Run as Administrator)".exe /SILENT
    wineserver -w
    sleep 2

    echo "[VARA] Installing VARA FM..."
    unzip -o -d /tmp "$MODULE_DIR/exe/VARA FM v4.3.9 setup.zip"
    wine /tmp/"VARA FM setup (Run as Administrator)".exe /SILENT
    wineserver -w
    sleep 2

    # Clean up installer files
    rm -f /tmp/"VARA setup (Run as Administrator)".exe
    rm -f /tmp/"VARA FM setup (Run as Administrator)".exe

    echo "[VARA] Installation complete"
}

config_vara () {
    echo "[VARA] Configuring VARA..."

    # Copy config files with callsign substitution
    cp "$MODULE_DIR/config/VARA.ini" "$WINEPREFIX/drive_c/VARA/VARA.ini"
    sed -i "s|XXXCALLSIGNXXX|$MYCALL|" "$WINEPREFIX/drive_c/VARA/VARA.ini"

    cp "$MODULE_DIR/config/VARAFM.ini" "$WINEPREFIX/drive_c/VARA FM/VARAFM.ini"
    sed -i "s|XXXCALLSIGNXXX|$MYCALL|" "$WINEPREFIX/drive_c/VARA FM/VARAFM.ini"

    # Install launcher script
    sudo cp "$MODULE_DIR/bin/start-vara-hf.sh" /opt/arcOS/bin/
    sudo chmod +x /opt/arcOS/bin/start-vara-hf.sh

    # Install desktop files
    mkdir -p "$HOME/.local/share/applications/wine/Programs/VARA"
    mkdir -p "$HOME/.local/share/applications/wine/Programs/VARA FM"
    cp "$MODULE_DIR/applications/VARA.desktop" "$HOME/.local/share/applications/wine/Programs/VARA/"
    cp "$MODULE_DIR/applications/VARA FM.desktop" "$HOME/.local/share/applications/wine/Programs/VARA FM/"

    # Install icons
    mkdir -p "$HOME/.local/share/icons/hicolor/48x48/apps"
    cp "$MODULE_DIR/icons/F302_VARA.0.png" "$HOME/.local/share/icons/hicolor/48x48/apps/"
    cp "$MODULE_DIR/icons/C497_VARAFM.0.png" "$HOME/.local/share/icons/hicolor/48x48/apps/"

    echo "[VARA] Configuration complete"
}

persist_vara () {
    echo "[VARA] Saving Wine prefix to persistent storage..."
    mkdir -p "$SAVE_DIR"/{icons,applications}

    # Save entire Wine prefix as tarball
    tar -C "$HOME" -cf "$SAVE_DIR/wine_vara.tar" .wine_vara_32

    # Save icons and desktop files for fast restore
    cp "$MODULE_DIR/icons/F302_VARA.0.png" "$SAVE_DIR/icons/"
    cp "$MODULE_DIR/icons/C497_VARAFM.0.png" "$SAVE_DIR/icons/"
    cp "$MODULE_DIR/applications/VARA.desktop" "$SAVE_DIR/applications/"
    cp "$MODULE_DIR/applications/VARA FM.desktop" "$SAVE_DIR/applications/"

    echo "[VARA] Saved to $SAVE_DIR"
}

register_vara () {
    REG_CODE=$(yad --title="VARA Registration..." \
        --window-icon="dialog-password-symbolic" \
        --undecorated \
        --form --borders=36 \
        --center \
        --fixed \
        --field="" \
        --text="Enter VARA Registration Code, or leave empty to continue without registration.\n\n" \
        --no-escape \
        --button="OK" \
        --buttons-layout=end)

    REG_CODE=$(echo -n "$REG_CODE" | sed 's/|//')

    if [ -n "$REG_CODE" ]; then
        echo "$REG_CODE" > "$SAVE_DIR/REGISTRATION_CODE"
        sed -i 's|^Registration Code=.*$|Registration Code='"$REG_CODE"'|' "$WINEPREFIX/drive_c/VARA/VARA.ini"
        sed -i 's|^Registration Code=.*$|Registration Code='"$REG_CODE"'|' "$WINEPREFIX/drive_c/VARA FM/VARAFM.ini"

        # Re-save tarball with registration
        tar -C "$HOME" -cf "$SAVE_DIR/wine_vara.tar" .wine_vara_32
    fi
}

deploy_vara () {
    if [ -f "$SAVE_DIR/wine_vara.tar" ]; then
        echo "[VARA] Restoring from saved tarball..."

        # Restore Wine prefix
        tar -C "$HOME" -xf "$SAVE_DIR/wine_vara.tar"

        # Restore icons
        mkdir -p "$HOME/.local/share/icons/hicolor/48x48/apps"
        cp "$SAVE_DIR/icons/F302_VARA.0.png" "$HOME/.local/share/icons/hicolor/48x48/apps/"
        cp "$SAVE_DIR/icons/C497_VARAFM.0.png" "$HOME/.local/share/icons/hicolor/48x48/apps/"

        # Restore desktop files
        mkdir -p "$HOME/.local/share/applications/wine/Programs/VARA"
        mkdir -p "$HOME/.local/share/applications/wine/Programs/VARA FM"
        cp "$SAVE_DIR/applications/VARA.desktop" "$HOME/.local/share/applications/wine/Programs/VARA/"
        cp "$SAVE_DIR/applications/VARA FM.desktop" "$HOME/.local/share/applications/wine/Programs/VARA FM/"

        # Add Categories if missing
        if ! grep -q "Categories" "$HOME/.local/share/applications/wine/Programs/VARA/VARA.desktop" 2>/dev/null; then
            echo "Categories=Wine" >> "$HOME/.local/share/applications/wine/Programs/VARA/VARA.desktop"
        fi
        if ! grep -q "Categories" "$HOME/.local/share/applications/wine/Programs/VARA FM/VARA FM.desktop" 2>/dev/null; then
            echo "Categories=Wine" >> "$HOME/.local/share/applications/wine/Programs/VARA FM/VARA FM.desktop"
        fi

        # Install launcher
        sudo cp "$MODULE_DIR/bin/start-vara-hf.sh" /opt/arcOS/bin/
        sudo chmod +x /opt/arcOS/bin/start-vara-hf.sh

        # Set Wine registry (COM port, ALSA)
        wine reg add "HKLM\\Software\\Wine\\Ports" /v COM1 /d /dev/digirig /t REG_SZ /f
        wine reg add "HKCU\\Software\\Wine\\Drivers\\winealsa.drv" /v ALSAInputDevices /d digirig-rx /t REG_MULTI_SZ /f
        wine reg add "HKCU\\Software\\Wine\\Drivers\\winealsa.drv" /v ALSAOutputDevices /d digirig-tx /t REG_MULTI_SZ /f
        wineserver -w

        # Restore registration code if saved
        if [ -f "$SAVE_DIR/REGISTRATION_CODE" ]; then
            REG_CODE=$(cat "$SAVE_DIR/REGISTRATION_CODE")
            sed -i 's|^Registration Code=.*$|Registration Code='"$REG_CODE"'|' "$WINEPREFIX/drive_c/VARA/VARA.ini"
            sed -i 's|^Registration Code=.*$|Registration Code='"$REG_CODE"'|' "$WINEPREFIX/drive_c/VARA FM/VARAFM.ini"
        fi

        echo "[VARA] Restore complete"
    else
        echo "[VARA] First boot - full installation"
        if command -v wine > /dev/null; then
            notify-send --icon=wine "VARA" "Preparing to install VARA (first boot)..."
            if prepare_vara && install_vara && config_vara && persist_vara; then
                register_vara
                notify-send --icon=info "VARA" "VARA installed successfully."
            else
                notify-send --icon=error "$MODULE" "$MODULE installation failed!"
                return 1
            fi
        else
            notify-send --icon=error "VARA" "Wine is not available. Installation failed!"
            return 1
        fi
    fi
}

deploy_vara

} # END OF MODULE COMMANDS FUNCTION

# Execute the module commands, and notify the user upon failure
module_commands > "$LOGFILE" 2>&1 || notify-send --icon=error "$MODULE" "$MODULE module failed!"
