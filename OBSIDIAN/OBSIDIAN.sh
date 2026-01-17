#!/bin/bash

#########################
# OBSIDIAN QRV MODULE   #
#########################
MODULE="OBSIDIAN"

# STATION INFO
source $HOME/.station-info

# PATHS
ARCOS_DATA=/arcHIVE
MODULE_DIR=$ARCOS_DATA/QRV/$MYCALL/arcos-linux-modules/USER/ko4dfo-user-modules/$MODULE
LOGFILE=$MODULE_DIR/$MODULE.log
SAVE_DIR=$ARCOS_DATA/QRV/$MYCALL/SAVED/$MODULE
########################

# GitHub release info
GITHUB_REPO="obsidianmd/obsidian-releases"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"

### GET TARGET VERSION ###
get_target_version () {
    # Check for user-pinned version first
    if [ -f "$SAVE_DIR/version.txt" ]; then
        cat "$SAVE_DIR/version.txt" | tr -d '[:space:]'
        return 0
    fi

    # Try to get latest from GitHub API
    if ping -c1 -W3 github.com &>/dev/null; then
        local latest=$(curl -s "$GITHUB_API" 2>/dev/null | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
        if [ -n "$latest" ]; then
            echo "$latest"
            return 0
        fi
    fi

    # Fall back to cached version
    if [ -f "$SAVE_DIR/cached_version.txt" ]; then
        cat "$SAVE_DIR/cached_version.txt" | tr -d '[:space:]'
        return 0
    fi

    # No version available
    return 1
}

### GET CACHED VERSION ###
get_cached_version () {
    if [ -f "$SAVE_DIR/cached_version.txt" ]; then
        cat "$SAVE_DIR/cached_version.txt" | tr -d '[:space:]'
    fi
}

### DOWNLOAD OBSIDIAN ###
download_obsidian () {
    local version="$1"
    local url="https://github.com/${GITHUB_REPO}/releases/download/v${version}/obsidian_${version}_amd64.deb"

    echo "=== Downloading Obsidian v${version} ==="

    (
        echo "10"; echo "# Connecting to GitHub..."
        sleep 1

        echo "20"; echo "# Downloading Obsidian v${version}..."
        if ! wget -q --show-progress -O "/tmp/obsidian_${version}_amd64.deb" "$url" 2>&1; then
            echo "100"; echo "# Download failed!"
            exit 1
        fi

        echo "70"; echo "# Verifying download..."
        if ! file "/tmp/obsidian_${version}_amd64.deb" | grep -q "Debian binary package"; then
            echo "100"; echo "# Invalid package file!"
            rm -f "/tmp/obsidian_${version}_amd64.deb"
            exit 1
        fi

        echo "85"; echo "# Caching package..."
        mkdir -p "$SAVE_DIR/packages"
        # Remove old versions
        rm -f "$SAVE_DIR/packages"/obsidian_*.deb
        mv "/tmp/obsidian_${version}_amd64.deb" "$SAVE_DIR/packages/"
        echo "$version" > "$SAVE_DIR/cached_version.txt"

        echo "100"; echo "# Download complete!"
    ) | zenity --progress --title="Downloading Obsidian" \
        --auto-close --no-cancel --width=400 2>/dev/null

    # Check if download succeeded
    if [ -f "$SAVE_DIR/packages/obsidian_${version}_amd64.deb" ]; then
        echo "=== Download complete ==="
        return 0
    else
        echo "=== Download failed ==="
        return 1
    fi
}

### INSTALL OBSIDIAN FROM CACHE ###
install_obsidian_from_cache () {
    echo "=== Installing Obsidian from cache ==="

    local deb_file=$(ls -1 "$SAVE_DIR/packages"/obsidian_*.deb 2>/dev/null | head -1)

    if [ -z "$deb_file" ] || [ ! -f "$deb_file" ]; then
        echo "No cached package found"
        return 1
    fi

    # Install using dpkg (dependencies are typically satisfied on arcOS)
    sudo dpkg --force-depends -i "$deb_file" 2>/dev/null

    # Verify installation
    if ! command -v obsidian &>/dev/null; then
        echo "Binary not found after dpkg, attempting dependency fix..."
        sudo apt-get install -f -y -qq 2>/dev/null
    fi

    if command -v obsidian &>/dev/null; then
        echo "=== Obsidian installation complete ==="
        return 0
    else
        echo "=== Obsidian installation failed ==="
        return 1
    fi
}

### SETUP CONFIG PERSISTENCE ###
setup_config_persistence () {
    echo "=== Setting up config persistence ==="

    local config_dir="$HOME/.config/obsidian"
    local save_config="$SAVE_DIR/config"

    # Create persistent config directory
    mkdir -p "$save_config"

    # Migrate existing config if it's not already a symlink
    if [ -d "$config_dir" ] && [ ! -L "$config_dir" ]; then
        echo "Migrating existing Obsidian config to persistent storage..."
        rsync -a "$config_dir/" "$save_config/"
        rm -rf "$config_dir"
    fi

    # Remove broken symlink if exists
    if [ -L "$config_dir" ] && [ ! -e "$config_dir" ]; then
        unlink "$config_dir"
    fi

    # Create symlink
    if [ ! -L "$config_dir" ]; then
        mkdir -p "$(dirname "$config_dir")"
        ln -s "$save_config" "$config_dir"
        echo "Config symlinked: $config_dir -> $save_config"
    fi

    echo "=== Config persistence ready ==="
}

### FIRST RUN SETUP ###
first_run_setup () {
    echo "=== First-run setup for Obsidian ==="

    # Check network connectivity
    if ! ping -c1 -W5 github.com &>/dev/null; then
        zenity --warning --title="Obsidian" \
            --text="No network connection.\n\nTo install Obsidian manually:\n1. Download .deb from obsidian.md/download\n2. Place in: $SAVE_DIR/packages/\n3. Reboot or re-run Station Setup" \
            --width=400 2>/dev/null
        notify-send --icon=dialog-warning "Obsidian" "No network - manual install required"
        return 1
    fi

    # Get latest version
    local version=$(get_target_version)
    if [ -z "$version" ]; then
        zenity --error --title="Obsidian" \
            --text="Could not determine Obsidian version.\nCheck network and try again." \
            --width=300 2>/dev/null
        return 1
    fi

    # Download
    if ! download_obsidian "$version"; then
        zenity --error --title="Obsidian" \
            --text="Download failed.\n\nTry manual install:\n1. Download from obsidian.md/download\n2. Place in: $SAVE_DIR/packages/" \
            --width=400 2>/dev/null
        return 1
    fi

    echo "=== First-run setup complete ==="
    return 0
}

### MODULE COMMANDS FUNCTION ###
module_commands () {

    # Create save directories
    mkdir -p "$SAVE_DIR/packages"
    mkdir -p "$SAVE_DIR/config"

    # Determine if we need to download
    local target_version=$(get_target_version)
    local cached_version=$(get_cached_version)
    local needs_download=false

    if [ -z "$cached_version" ]; then
        # No cache at all - first run
        needs_download=true
    elif [ -n "$target_version" ] && [ "$target_version" != "$cached_version" ]; then
        # Version mismatch - update available
        needs_download=true
        echo "Update available: $cached_version -> $target_version"
    fi

    # Download if needed and network available
    if [ "$needs_download" = true ]; then
        if [ -n "$target_version" ]; then
            if ping -c1 -W3 github.com &>/dev/null; then
                download_obsidian "$target_version" || {
                    # Download failed but we might have old cache
                    if [ -z "$cached_version" ]; then
                        first_run_setup
                    fi
                }
            elif [ -z "$cached_version" ]; then
                # No network AND no cache - first run without network
                first_run_setup
                return $?
            fi
        elif [ -z "$cached_version" ]; then
            first_run_setup
            return $?
        fi
    fi

    # Install Obsidian if not present (overlay wipes /usr each reboot)
    if ! command -v obsidian &>/dev/null; then
        if ! install_obsidian_from_cache; then
            echo "Failed to install Obsidian"
            notify-send --icon=dialog-error "Obsidian" "Installation failed - check $LOGFILE"
            return 1
        fi
    fi

    # Setup config persistence
    setup_config_persistence

    # Report success
    local installed_version=$(get_cached_version)
    echo "Obsidian module complete (v${installed_version})"

} # END OF MODULE COMMANDS FUNCTION

# Execute the module commands, and notify the user upon failure
module_commands > $LOGFILE 2>&1 || notify-send --icon=error "$MODULE" "$MODULE module failed!"
