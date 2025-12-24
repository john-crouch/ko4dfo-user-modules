#!/bin/bash

###########################
# SECURE-LOGIN QRV MODULE #
###########################
MODULE="SECURE-LOGIN"

# STATION INFO
source $HOME/.station-info

# PATHS
ARCOS_DATA=/arcHIVE
MODULE_DIR=$ARCOS_DATA/QRV/$MYCALL/arcos-linux-modules/USER/ko4dfo-user-modules/$MODULE
LOGFILE=$MODULE_DIR/$MODULE.log
SAVE_DIR=$ARCOS_DATA/QRV/$MYCALL/SAVED/$MODULE

# SECRETS-SPECIFIC PATHS
SECRETS_CONTAINER=$ARCOS_DATA/QRV/$MYCALL/secrets.luks
SECRETS_MOUNT=/mnt/secrets
SECRETS_MAPPER="secrets-$MYCALL"
MAX_ATTEMPTS=3
########################

### MODULE COMMANDS FUNCTION ###
module_commands () {
    echo "=== SECURE-LOGIN module starting ==="
    echo "Container: $SECRETS_CONTAINER"

    # Install helper scripts to /opt/arcOS/bin/
    echo "Installing secrets scripts..."
    sudo cp ${MODULE_DIR}/bin/secrets-setup /opt/arcOS/bin/
    sudo cp ${MODULE_DIR}/bin/secrets-password /opt/arcOS/bin/
    sudo chmod +x /opt/arcOS/bin/secrets-setup
    sudo chmod +x /opt/arcOS/bin/secrets-password
    echo "Scripts installed: secrets-setup, secrets-password"

    # Check if container exists
    if [ ! -f "$SECRETS_CONTAINER" ]; then
        echo "No secrets container found at $SECRETS_CONTAINER"
        echo "Run 'secrets-setup' to create one, or continue without secure password storage."
        notify-send --icon=dialog-information "$MODULE" "No secrets container. Run 'secrets-setup' to enable secure password storage."
        return 0
    fi

    # Always prompt for password (needed for system login and keyring)
    local attempt=1
    local authenticated=false

    # Detect dark mode and choose appropriate logo (centered version for dialog)
    GTK_THEME=$(gsettings get org.cinnamon.desktop.interface gtk-theme 2>/dev/null || \
                gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null || echo "")
    if echo "$GTK_THEME" | grep -qi "dark"; then
        ARCOS_LOGO="$MODULE_DIR/arcos-logo-small-centered.png"       # White logo for dark themes
    else
        ARCOS_LOGO="$MODULE_DIR/arcos-logo-dark-small-centered.png"  # Dark logo for light themes
    fi
    echo "Theme: $GTK_THEME -> Using logo: $ARCOS_LOGO"

    while [ $attempt -le $MAX_ATTEMPTS ] && [ "$authenticated" = "false" ]; do
        echo "Password attempt $attempt of $MAX_ATTEMPTS"

        PASSWORD=$(yad --form \
            --title="arcOS Secure Login" \
            --window-icon="$ARCOS_LOGO" \
            --image="$ARCOS_LOGO" \
            --image-on-top \
            --text-align=center \
            --width=420 \
            --borders=20 \
            --center \
            --on-top \
            --skip-taskbar \
            --button="Unlock:0" \
            --button="Cancel:1" \
            --field="<b>Enter station unlock password</b>:LBL" "" \
            --field=":H" "" \
            --field="Attempt $attempt of $MAX_ATTEMPTS:LBL" "" \
            2>/dev/null | cut -d'|' -f2)

        # User cancelled or timeout
        if [ -z "$PASSWORD" ]; then
            echo "No password provided, skipping secure login"
            notify-send --icon=dialog-warning "$MODULE" "Secure login skipped. System password not set."
            return 0
        fi

        # Check if already unlocked (e.g., from previous run)
        if [ -b "/dev/mapper/$SECRETS_MAPPER" ]; then
            echo "Secrets container already unlocked, verifying password..."
            # Verify password is correct by testing against LUKS
            if echo -n "$PASSWORD" | sudo cryptsetup open --test-passphrase "$SECRETS_CONTAINER" - 2>/dev/null; then
                echo "Password verified"
                authenticated=true
            else
                echo "Password incorrect"
                attempt=$((attempt + 1))
                if [ $attempt -le $MAX_ATTEMPTS ]; then
                    yad --error \
                        --title="Authentication Failed" \
                        --window-icon="dialog-warning" \
                        --image="dialog-password" \
                        --width=320 \
                        --center \
                        --button="Try Again:0" \
                        --text="<b>Incorrect password</b>\n\nPlease try again." \
                        2>/dev/null
                fi
            fi
        else
            # Try to unlock with password
            if echo -n "$PASSWORD" | sudo cryptsetup open "$SECRETS_CONTAINER" "$SECRETS_MAPPER" - 2>&1; then
                echo "Container unlocked successfully"
                authenticated=true
            else
                echo "Failed to unlock container (wrong password?)"
                attempt=$((attempt + 1))
                if [ $attempt -le $MAX_ATTEMPTS ]; then
                    yad --error \
                        --title="Authentication Failed" \
                        --window-icon="dialog-warning" \
                        --image="dialog-password" \
                        --width=320 \
                        --center \
                        --button="Try Again:0" \
                        --text="<b>Incorrect password</b>\n\nPlease try again." \
                        2>/dev/null
                fi
            fi
        fi
    done

    if [ "$authenticated" = "false" ]; then
        echo "Max attempts reached, giving up"
        notify-send --icon=dialog-error "$MODULE" "Authentication failed after $MAX_ATTEMPTS attempts."
        unset PASSWORD
        return 1
    fi

    # Set system password using the successful password
    echo "Setting system password..."
    if echo "user:$PASSWORD" | sudo chpasswd 2>&1; then
        echo "System password set successfully"
    else
        echo "ERROR: Failed to set system password"
        notify-send --icon=dialog-error "$MODULE" "Failed to set system password!"
    fi

    # Mount the container for other secrets
    if [ ! -d "$SECRETS_MOUNT" ]; then
        sudo mkdir -p "$SECRETS_MOUNT"
    fi

    if ! mountpoint -q "$SECRETS_MOUNT"; then
        if sudo mount "/dev/mapper/$SECRETS_MAPPER" "$SECRETS_MOUNT" 2>&1; then
            echo "Secrets mounted at $SECRETS_MOUNT"
            # Set permissions so user can access
            sudo chown user:user "$SECRETS_MOUNT"
        else
            echo "WARNING: Failed to mount secrets container"
        fi
    else
        echo "Secrets already mounted at $SECRETS_MOUNT"
    fi

    # List available secrets (for logging)
    if [ -d "$SECRETS_MOUNT" ]; then
        echo "Available secrets:"
        ls -la "$SECRETS_MOUNT" 2>/dev/null
    fi

    # Set up Login keyring with persistent ENCRYPTED storage
    echo "Setting up Login keyring..."
    KEYRINGS_PERSISTENT="$SECRETS_MOUNT/keyrings"
    KEYRINGS_LOCAL="$HOME/.local/share/keyrings"

    # Create persistent keyrings directory if needed
    if [ ! -d "$KEYRINGS_PERSISTENT" ]; then
        mkdir -p "$KEYRINGS_PERSISTENT"
        chmod 700 "$KEYRINGS_PERSISTENT"
        echo "Created persistent keyrings directory"
    fi

    # Ensure parent directory exists
    mkdir -p "$HOME/.local/share"

    # Check if CORE KEYRING module mounted an unencrypted keyring here
    if mountpoint -q "$KEYRINGS_LOCAL"; then
        echo "Unmounting CORE keyring (replacing with encrypted version)..."
        sudo umount "$KEYRINGS_LOCAL" 2>/dev/null || true
        rmdir "$KEYRINGS_LOCAL" 2>/dev/null || true
    fi

    # Remove existing keyrings dir/symlink and create symlink to encrypted storage
    if [ -L "$KEYRINGS_LOCAL" ]; then
        rm "$KEYRINGS_LOCAL"
        echo "Removed existing symlink"
    elif [ -d "$KEYRINGS_LOCAL" ]; then
        # Move any existing keyrings to persistent storage
        cp -a "$KEYRINGS_LOCAL"/* "$KEYRINGS_PERSISTENT"/ 2>/dev/null || true
        rm -rf "$KEYRINGS_LOCAL"
        echo "Migrated existing keyrings to encrypted storage"
    fi
    ln -s "$KEYRINGS_PERSISTENT" "$KEYRINGS_LOCAL"
    echo "Keyring symlinked: $KEYRINGS_LOCAL -> $KEYRINGS_PERSISTENT (encrypted)"

    # Configure keyrings directory
    KEYRINGS_DIR="$HOME/.local/share/keyrings"

    # Remove any "Default keyring" - we only want Login keyring
    if [ -f "$KEYRINGS_DIR/Default_keyring.keyring" ]; then
        rm -f "$KEYRINGS_DIR/Default_keyring.keyring"
        echo "Removed unwanted Default_keyring.keyring"
    fi

    # Set login as default BEFORE daemon restart (prevents Default keyring creation)
    echo "login" > "$KEYRINGS_DIR/default"
    chmod 600 "$KEYRINGS_DIR/default"
    echo "Set 'login' as default keyring"

    # Create login.keyring if it doesn't exist (BEFORE daemon restart)
    if [ ! -f "$KEYRINGS_DIR/login.keyring" ]; then
        echo "No login.keyring found, creating via PAM interface..."
        # gnome-keyring-daemon --login expects null-terminated password on stdin
        # This is the PAM module interface - creates keyring WITHOUT GUI prompt
        KEYRING_OUTPUT=$(printf '%s\0' "$PASSWORD" | gnome-keyring-daemon --login 2>&1)
        KEYRING_EXIT=$?
        echo "$KEYRING_OUTPUT"

        if [ $KEYRING_EXIT -eq 0 ]; then
            echo "Login keyring created successfully"
        else
            echo "WARNING: Failed to create login keyring"
        fi
    fi

    # Unlock the Login keyring via PAM interface
    # This requires starting a fresh daemon - the only way to unlock without GUI

    # Step 1: Disable socket to prevent auto-respawn
    echo "Disabling gnome-keyring socket..."
    systemctl --user mask gnome-keyring-daemon.socket 2>&1 || true

    # Step 2: Stop service and kill ALL existing daemons
    echo "Stopping all gnome-keyring daemons..."
    systemctl --user stop gnome-keyring-daemon.service 2>&1 || true

    # Kill each daemon by PID (pkill pattern matching is unreliable)
    for pid in $(pgrep -f gnome-keyring-daemon); do
        echo "Killing gnome-keyring-daemon PID $pid"
        kill -9 "$pid" 2>/dev/null || true
    done
    sleep 0.5

    # Verify all killed
    if pgrep -f gnome-keyring-daemon > /dev/null 2>&1; then
        echo "WARNING: Some daemons still running after kill"
        pgrep -af gnome-keyring-daemon
    else
        echo "All gnome-keyring daemons stopped"
    fi

    # Step 3: Start fresh daemon with --login (receives password, unlocks keyring)
    # Note: --start is incompatible with --login, use --daemonize only
    echo "Starting gnome-keyring-daemon with login password..."
    KEYRING_OUTPUT=$(printf '%s\0' "$PASSWORD" | gnome-keyring-daemon \
        --daemonize \
        --components=secrets,pkcs11 \
        --login 2>&1)
    echo "Daemon output: $KEYRING_OUTPUT"

    # Export environment variables
    if [ -n "$KEYRING_OUTPUT" ]; then
        eval "$KEYRING_OUTPUT" 2>/dev/null || true
    fi

    # Step 4: Re-enable socket for normal operation
    echo "Re-enabling gnome-keyring socket..."
    systemctl --user unmask gnome-keyring-daemon.socket 2>&1 || true

    # Verify the keyring is unlocked
    sleep 0.5
    echo "Verifying keyring unlock..."
    LOCKED_STATUS=$(gdbus call --session \
        --dest org.freedesktop.secrets \
        --object-path /org/freedesktop/secrets/collection/login \
        --method org.freedesktop.DBus.Properties.Get \
        org.freedesktop.Secret.Collection Locked 2>&1)
    echo "Locked status: $LOCKED_STATUS"

    if echo "$LOCKED_STATUS" | grep -q "false"; then
        echo "Login keyring unlocked successfully"
    else
        echo "WARNING: Login keyring may still be locked"
    fi

    # Clear password from memory
    unset PASSWORD

    echo "=== SECURE-LOGIN module complete ==="
}
# END OF MODULE COMMANDS FUNCTION

module_commands > $LOGFILE 2>&1 || notify-send --icon=error "$MODULE" "$MODULE module failed!"
