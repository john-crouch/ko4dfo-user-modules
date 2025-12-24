# SECURE-LOGIN Module

Unified password management for arcOS stations using LUKS encryption.

## Overview

The SECURE-LOGIN module provides a single-password solution for arcOS Live Linux stations. Instead of storing password hashes in plaintext on the exFAT partition, this module uses a LUKS-encrypted container where **the container password IS your system password**.

### Key Features

- **Single password** - One password unlocks everything (LUKS container, system login, GNOME keyring)
- **Encrypted storage** - Secrets stored in LUKS2-encrypted container (AES-XTS-512)
- **Persistent keyring** - GNOME Login keyring stored inside encrypted container
- **Theme-aware UI** - Login dialog adapts to light/dark themes with arcOS branding
- **No timeout** - Password dialog waits indefinitely for user input

## How It Works

```
Boot -> SECURE-LOGIN module runs -> Password prompt (arcOS branded)
                                           |
                                 LUKS container unlocked
                                           |
                    +----------------------+----------------------+
                    |                      |                      |
            System password         Secrets mounted        Keyring unlocked
               set via               at /mnt/secrets        and available
              chpasswd                                       for apps
```

### Boot Flow

1. **Password Prompt** - Polished yad dialog with arcOS logo (theme-aware)
2. **LUKS Unlock** - Container unlocked with entered password
3. **System Password** - Same password set as system login via `chpasswd`
4. **Mount Secrets** - Container mounted at `/mnt/secrets`
5. **Keyring Setup** - GNOME Login keyring symlinked to encrypted storage
6. **Keyring Unlock** - Fresh daemon started with password via PAM interface

## Files

```
SECURE-LOGIN/
├── SECURE-LOGIN.sh                      # Main module script (304 lines)
├── README.md                            # This documentation
├── SECURE-LOGIN.log                     # Runtime log (recreated each boot)
├── arcos-logo-small-centered.png        # White logo for dark themes (340x110)
├── arcos-logo-dark-small-centered.png   # Dark logo for light themes (340x110)
└── bin/
    ├── secrets-setup                    # First-time container creation
    ├── secrets-password                 # Password change utility
    └── create-login-keyring             # Programmatic keyring creation (Python)
```

## Installation

### First-Time Setup

1. Add `SECURE-LOGIN` to your `ENABLED_MODULES` file
2. Reboot - module will notify you to run setup
3. Run `secrets-setup` to create your encrypted container:I

```bash
secrets-setup
```

This will:
- Create a 32MB LUKS2-encrypted container at `/arcHIVE/QRV/$MYCALL/secrets.luks`
- Prompt for a password (used for both container and system login)
- Format the container with ext4
- Set your system password
- Optionally remove the old plaintext `.passwd` file

### Subsequent Boots

On each boot, the module:
1. Displays the arcOS-branded password dialog (waits indefinitely)
2. Unlocks the LUKS container
3. Sets the system password
4. Mounts secrets at `/mnt/secrets`
5. Symlinks keyrings to encrypted storage
6. Kills existing keyring daemons and starts fresh with password
7. Verifies keyring is unlocked via D-Bus

## Commands

### secrets-setup

Creates the encrypted secrets container. Run once during initial setup.

```bash
secrets-setup
```

**Features:**
- Interactive password entry with confirmation
- Detects and offers to replace existing containers
- Creates 32MB LUKS2 container (AES-XTS-512, SHA256)
- Sets system password to match container password
- Offers to remove old `.passwd` file

### secrets-password

Changes both the LUKS container password and system password together.

```bash
secrets-password
```

**Features:**
- Verifies current password before allowing change
- Updates both LUKS and system password atomically
- Works whether container is open or closed

## Technical Details

### LUKS Container

| Property | Value |
|----------|-------|
| Format | LUKS2 |
| Cipher | aes-xts-plain64 |
| Key Size | 512 bits |
| Hash | SHA256 |
| Location | `/arcHIVE/QRV/$MYCALL/secrets.luks` |
| Size | 32MB (16MB header + 16MB storage) |
| Mount Point | `/mnt/secrets` |
| Mapper Name | `secrets-$MYCALL` |

### GNOME Keyring Integration

The Login keyring is stored inside the encrypted container:

```
~/.local/share/keyrings -> /mnt/secrets/keyrings (symlink)
```

**Keyring unlock process:**

1. Mask `gnome-keyring-daemon.socket` (prevent auto-respawn)
2. Stop systemd service and kill all existing daemons by PID
3. Start fresh daemon with `--daemonize --components=secrets,pkcs11 --login`
4. Password passed via stdin (null-terminated for PAM interface)
5. Unmask socket for normal operation
6. Verify unlock via D-Bus: `org.freedesktop.Secret.Collection.Locked = false`

**Why this approach:**
- `--login` only works when it's the FIRST daemon to start
- Multiple daemons cause D-Bus service ownership confusion
- Socket activation can respawn daemons unexpectedly
- `pkill` pattern matching is unreliable; killing by PID works

### Theme Detection

The login dialog automatically adapts to your GTK theme:

```bash
GTK_THEME=$(gsettings get org.cinnamon.desktop.interface gtk-theme)
if [[ "$GTK_THEME" =~ [Dd]ark ]]; then
    # Use white logo (arcos-logo-small-centered.png)
else
    # Use dark logo (arcos-logo-dark-small-centered.png)
fi
```

### Login Dialog (yad)

| Property | Value |
|----------|-------|
| Tool | yad (Yet Another Dialog) |
| Logo | arcOS logo, 340x110, centered |
| Width | 420px |
| Borders | 20px padding |
| Position | Centered, always-on-top |
| Buttons | "Unlock" / "Cancel" |
| Timeout | None (waits indefinitely) |
| Taskbar | Hidden |

## Storage Locations

| Item | Location | Persistence |
|------|----------|-------------|
| LUKS Container | `/arcHIVE/QRV/$MYCALL/secrets.luks` | Persistent (exFAT) |
| Mount Point | `/mnt/secrets` | Runtime only |
| Keyrings | `/mnt/secrets/keyrings` | Encrypted, persistent |
| Keyring Symlink | `~/.local/share/keyrings` | Runtime only |
| Helper Scripts | `/opt/arcOS/bin/` | Runtime only |
| Logo Files | `$MODULE_DIR/*.png` | Persistent (exFAT) |

## Security Considerations

### Strengths

- Password never stored in plaintext
- LUKS2 with strong cipher (AES-XTS-512)
- Keyring protected by same encryption
- Password cleared from memory after use (`unset PASSWORD`)
- Container password and system password always in sync
- Default keyring forced to "login" (prevents unencrypted Default keyring)

### Limitations

- Container stored on exFAT (no Unix permissions) - relies on LUKS encryption
- Password visible to root during `chpasswd` call
- 32MB container limits total secret storage
- Single password point of failure (lose password = lose secrets)

### Recommendations

- Use a strong, memorable password
- Keep a secure backup of critical secrets elsewhere
- The container file can be backed up (it's encrypted)

## Troubleshooting

### "No secrets container found"

Run `secrets-setup` to create the encrypted container.

### Wrong password on boot

You have 3 attempts. After failure:
- System boots without password set
- Reboot to try again

### Keyring not unlocking

Check the log file:
```bash
cat $MODULE_DIR/SECURE-LOGIN.log
```

Look for:
- "All gnome-keyring daemons stopped" - daemons killed successfully
- "Daemon output:" - should show GNOME_KEYRING_CONTROL path
- "Locked status: (<false>,)" - keyring unlocked

### Keyring not visible in Seahorse

Multiple daemon processes may be confusing D-Bus. The module masks the socket and kills by PID to prevent this. If issues persist:
```bash
systemctl --user mask gnome-keyring-daemon.socket
for pid in $(pgrep -f gnome-keyring-daemon); do kill -9 $pid; done
# Then run station-setup again
systemctl --user unmask gnome-keyring-daemon.socket
```

### Password out of sync

Use `secrets-password` to reset both LUKS and system password.

## Dependencies

- `cryptsetup` - LUKS container management
- `yad` - Enhanced dialog tool (fork of zenity)
- `gnome-keyring-daemon` - Keyring management
- `gdbus` - D-Bus command-line tool (for verification)
- `gsettings` - Theme detection
- `chpasswd` - System password setting

## Module Integration

### ENABLED_MODULES

Add to your `ENABLED_MODULES` file:
```
SECURE-LOGIN
```

### Disabling CORE KEYRING

If using SECURE-LOGIN, disable the CORE KEYRING module to avoid conflicts:
```bash
mv /arcHIVE/.../CORE/40_KEYRING.sh /arcHIVE/.../CORE/KEYRING/
```

The module automatically unmounts any CORE keyring mount and removes unwanted Default_keyring.keyring.
