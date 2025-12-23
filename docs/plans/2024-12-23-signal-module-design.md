# Signal Module Design

## Overview

Install Signal Desktop with encrypted, persistent storage. Messages, keys, and contacts are stored in a LUKS-encrypted container on `/arcHIVE` that mounts only while Signal is running.

## Key Decisions

- **Encryption:** LUKS container (5GB) - hides metadata unlike gocryptfs
- **Installation:** Cached .deb packages - offline reinstall each boot
- **Password storage:** gnome-keyring via `gio mount` - no extra libraries needed
- **Lifecycle:** Mount on launch, unmount on close - data only exposed while running

## Directory Structure

```
/arcHIVE/QRV/KO4DFO/
├── arcos-linux-modules/USER/ko4dfo-user-modules/
│   └── SIGNAL/
│       ├── SIGNAL.sh          # Main module script
│       ├── SIGNAL.log         # Module execution log
│       └── bin/
│           └── signal-launch  # Wrapper script for mount/launch/unmount
│
└── SAVED/SIGNAL/
    ├── signal.luks           # 5GB encrypted LUKS container
    ├── packages/             # Cached .deb files for offline install
    │   ├── signal-desktop_*.deb
    │   └── deps/             # Dependencies
    └── signal-launch.desktop # Desktop launcher file
```

## LUKS Container Management

### Creation (First Run)

```bash
# Create 5GB sparse file
dd if=/dev/zero of=$SAVE_DIR/signal.luks bs=1M count=5120

# Format as LUKS (prompts for password)
cryptsetup luksFormat $SAVE_DIR/signal.luks

# Open, format inner filesystem, close
cryptsetup open $SAVE_DIR/signal.luks signal-crypt
mkfs.ext4 /dev/mapper/signal-crypt
cryptsetup close signal-crypt
```

### Runtime Mount Flow

1. Attach container to loop device: `losetup --find --show signal.luks`
2. `gio mount -d /dev/loopX` - prompts for password (or retrieves from keyring)
3. Container mounts to `/run/media/$USER/signal-crypt/`
4. Signal's `~/.config/Signal` symlinks to this mount point

### Unmount Flow

1. `gio mount -u /run/media/$USER/signal-crypt/`
2. `losetup -d /dev/loopX`

### Password Storage

- First unlock: `gio mount` shows GTK dialog with "Remember password" checkbox
- User checks the box -> password stored in gnome-keyring under `gvfs-luks-uuid` schema
- Subsequent launches: `gio mount` retrieves password silently from keyring

## Signal Installation

### Initial Package Download

```bash
# Add Signal's official apt repository
wget -qO- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > signal-keyring.gpg
echo "deb [arch=amd64 signed-by=...] https://updates.signal.org/desktop/apt xenial main" \
    | sudo tee /etc/apt/sources.list.d/signal.list
sudo apt update

# Download Signal and dependencies without installing
apt download signal-desktop
apt-cache depends signal-desktop | grep Depends | \
    sed 's/.*Depends: //' | xargs apt download

# Cache everything to persistent storage
mv *.deb $SAVE_DIR/packages/
```

### Each Boot

```bash
# Check if Signal binary exists (overlay wipes /usr each reboot)
if ! command -v signal-desktop &>/dev/null; then
    sudo dpkg -i $SAVE_DIR/packages/*.deb 2>/dev/null
    sudo apt-get install -f -y
fi
```

## Launcher

### Wrapper Script (`signal-launch`)

```bash
#!/bin/bash
CONTAINER="$SAVE_DIR/signal.luks"
MOUNT_NAME="signal-crypt"
MOUNT_POINT="/run/media/$USER/$MOUNT_NAME"
CONFIG_DIR="$HOME/.config/Signal"

# Find or create loop device
LOOP=$(losetup -j "$CONTAINER" | cut -d: -f1)
if [ -z "$LOOP" ]; then
    LOOP=$(losetup --find --show "$CONTAINER")
fi

# Mount via gio (uses keyring automatically)
if ! mountpoint -q "$MOUNT_POINT"; then
    gio mount -d "$LOOP"
fi

# Ensure config symlink points to encrypted storage
mkdir -p "$MOUNT_POINT/config"
ln -sfn "$MOUNT_POINT/config" "$CONFIG_DIR"

# Launch Signal, wait for exit
signal-desktop --no-sandbox "$@"
EXIT_CODE=$?

# Cleanup: unmount and detach loop
gio mount -u "$MOUNT_POINT" 2>/dev/null
losetup -d "$LOOP" 2>/dev/null

exit $EXIT_CODE
```

### Desktop File

```ini
[Desktop Entry]
Name=Signal (Encrypted)
Comment=Private messaging with encrypted local storage
Exec=/opt/arcOS/bin/signal-launch %U
Icon=signal-desktop
Type=Application
Categories=Network;InstantMessaging;
```

## First-Run Experience

1. **Detect first run:** Check if `$SAVE_DIR/signal.luks` exists
2. **Create LUKS container:** Use `zenity --password` for password entry
3. **Download Signal packages:** Show progress via `zenity --progress`
4. **Initial mount:** `gio mount` prompts; user checks "Remember password"
5. **Launch Signal:** User completes Signal's own setup
6. **Notify:** `notify-send` confirms encrypted storage is ready

## Error Handling

- Network failure during first run: Notify user, exit gracefully
- LUKS creation fails: Clean up partial files, notify user
- Mount fails: Notify with hint to check password in Seahorse

## Dependencies

- `cryptsetup` (for LUKS)
- `gio` (GNOME I/O, for keyring-integrated mount)
- `zenity` (for first-run dialogs)
- Signal Desktop .deb and its dependencies
