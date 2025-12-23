#!/bin/bash

#######################
#  SIGNAL QRV MODULE  #
#######################
MODULE="SIGNAL"

# STATION INFO
source $HOME/.station-info

# PATHS
ARCOS_DATA=/arcHIVE
MODULE_DIR=$ARCOS_DATA/QRV/$MYCALL/arcos-linux-modules/USER/ko4dfo-user-modules/$MODULE
LOGFILE=$MODULE_DIR/$MODULE.log
SAVE_DIR=$ARCOS_DATA/QRV/$MYCALL/SAVED/$MODULE
CONTAINER="$SAVE_DIR/signal.luks"
CONTAINER_SIZE_MB=5120
########################

### FIRST RUN SETUP ###
first_run_setup () {
    echo "=== First-run setup for Signal ==="

    # Create save directories
    mkdir -p "$SAVE_DIR/packages"

    # Get password for LUKS container
    PASSWORD=$(zenity --password \
        --title="Create Signal Encrypted Storage" \
        --text="Enter a password to encrypt your Signal data.\nThis password will be saved in your keyring." \
        2>/dev/null)

    if [ -z "$PASSWORD" ]; then
        zenity --error --text="No password provided. Setup cancelled." 2>/dev/null
        return 1
    fi

    # Confirm password
    PASSWORD_CONFIRM=$(zenity --password \
        --title="Confirm Password" \
        --text="Re-enter your password to confirm:" \
        2>/dev/null)

    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        zenity --error --text="Passwords do not match. Setup cancelled." 2>/dev/null
        return 1
    fi

    # Create LUKS container with progress
    (
        echo "10"; echo "# Creating encrypted container (5GB)..."
        dd if=/dev/zero of="$CONTAINER" bs=1M count=$CONTAINER_SIZE_MB status=none 2>&1

        echo "40"; echo "# Formatting as LUKS..."
        echo -n "$PASSWORD" | cryptsetup luksFormat --batch-mode "$CONTAINER" - 2>&1

        echo "60"; echo "# Opening container..."
        echo -n "$PASSWORD" | cryptsetup open "$CONTAINER" signal-crypt-setup - 2>&1

        echo "80"; echo "# Creating filesystem..."
        mkfs.ext4 -q /dev/mapper/signal-crypt-setup 2>&1

        echo "90"; echo "# Closing container..."
        cryptsetup close signal-crypt-setup 2>&1

        echo "100"; echo "# Done!"
    ) | zenity --progress --title="Setting up Signal Encrypted Storage" \
        --auto-close --no-cancel --width=400 2>/dev/null

    if [ ! -f "$CONTAINER" ]; then
        zenity --error --text="Failed to create encrypted container." 2>/dev/null
        return 1
    fi

    # Download Signal packages
    download_signal_packages

    echo "=== First-run setup complete ==="
    notify-send --icon=signal-desktop "Signal" "Encrypted storage created. Launch Signal from the menu."
}

### DOWNLOAD SIGNAL PACKAGES ###
download_signal_packages () {
    echo "=== Downloading Signal packages ==="

    # Check network connectivity
    if ! ping -c1 -W5 updates.signal.org &>/dev/null; then
        zenity --warning --text="No network connection. Signal packages not downloaded.\nRun this module again when connected." 2>/dev/null
        return 1
    fi

    (
        echo "5"; echo "# Adding Signal repository..."

        # Add Signal's GPG key
        wget -qO- https://updates.signal.org/desktop/apt/keys.asc | \
            gpg --dearmor | sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null

        # Add repository
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main" | \
            sudo tee /etc/apt/sources.list.d/signal-xenial.list > /dev/null

        echo "20"; echo "# Updating package lists..."
        sudo apt-get update -qq 2>&1

        echo "40"; echo "# Downloading Signal Desktop..."
        cd /tmp
        apt-get download signal-desktop 2>&1

        echo "60"; echo "# Downloading dependencies..."
        # Get dependencies and download them
        apt-cache depends signal-desktop 2>/dev/null | \
            grep "Depends:" | sed 's/.*Depends: //' | \
            while read dep; do
                # Only download if not already installed
                if ! dpkg -s "$dep" &>/dev/null; then
                    apt-get download "$dep" 2>/dev/null
                fi
            done

        echo "80"; echo "# Caching packages..."
        mv -f /tmp/signal-desktop*.deb "$SAVE_DIR/packages/" 2>/dev/null
        mv -f /tmp/*.deb "$SAVE_DIR/packages/" 2>/dev/null

        echo "100"; echo "# Done!"
    ) | zenity --progress --title="Downloading Signal" \
        --auto-close --no-cancel --width=400 2>/dev/null

    echo "=== Signal packages downloaded ==="
}

### INSTALL SIGNAL FROM CACHE ###
install_signal_from_cache () {
    echo "=== Installing Signal from cache ==="

    if [ ! -d "$SAVE_DIR/packages" ] || [ -z "$(ls -A "$SAVE_DIR/packages" 2>/dev/null)" ]; then
        echo "No cached packages found"
        return 1
    fi

    # Install all cached packages
    sudo dpkg -i "$SAVE_DIR/packages"/*.deb 2>/dev/null || true

    # Fix any missing dependencies
    sudo apt-get install -f -y -qq 2>/dev/null

    echo "=== Signal installation complete ==="
}

### MODULE COMMANDS FUNCTION ###
module_commands () {

    # Create save directory
    mkdir -p "$SAVE_DIR"

    # First-run setup if container doesn't exist
    if [ ! -f "$CONTAINER" ]; then
        first_run_setup
        if [ $? -ne 0 ]; then
            echo "First-run setup failed or was cancelled"
            return 1
        fi
    fi

    # Install Signal if not present (overlay wipes /usr each reboot)
    if ! command -v signal-desktop &>/dev/null; then
        install_signal_from_cache
    fi

    # Install launcher script
    sudo mkdir -p /opt/arcOS/bin
    sudo cp "$MODULE_DIR/bin/signal-launch" /opt/arcOS/bin/
    sudo chmod +x /opt/arcOS/bin/signal-launch

    # Create desktop launcher in persistent storage if not exists
    if [ ! -f "$SAVE_DIR/signal-launch.desktop" ]; then
        cat > "$SAVE_DIR/signal-launch.desktop" << 'DESKTOP'
[Desktop Entry]
Name=Signal (Encrypted)
Comment=Private messaging with encrypted local storage
Exec=/opt/arcOS/bin/signal-launch %U
Icon=signal-desktop
Type=Application
Categories=Network;InstantMessaging;
StartupWMClass=Signal
DESKTOP
    fi

    # Install desktop file
    mkdir -p "$HOME/.local/share/applications"
    cp "$SAVE_DIR/signal-launch.desktop" "$HOME/.local/share/applications/"

    # Remove original Signal desktop file (force use of encrypted launcher)
    sudo rm -f /usr/share/applications/signal-desktop.desktop

    echo "Signal module setup complete"

} # END OF MODULE COMMANDS FUNCTION

# Execute the module commands, and notify the user upon failure
module_commands > $LOGFILE 2>&1 || notify-send --icon=error "$MODULE" "$MODULE module failed!"
