# Obsidian Module Design

## Overview

arcOS USER module for Obsidian note-taking application. Provides offline installation via cached .deb and persists application configuration across reboots.

## Design Decisions

- **Vault management**: User responsibility (not module scope)
- **Config persistence**: Symlink `~/.config/obsidian/` to persistent storage
- **.deb acquisition**: Automated download from GitHub releases
- **Version strategy**: Latest by default, user can pin via `version.txt`
- **First-run UX**: Interactive Zenity progress dialogs

## Module Structure

```
OBSIDIAN/
├── OBSIDIAN.sh           # Main module script
├── OBSIDIAN.log          # Runtime log (gitignored)
├── README                 # User instructions
└── bin/
    └── (none required)
```

## Persistent Storage Layout

Location: `/arcHIVE/QRV/$MYCALL/SAVED/OBSIDIAN/`

```
SAVED/OBSIDIAN/
├── packages/
│   └── obsidian_X.X.X_amd64.deb   # Cached installer
├── config/                         # Symlink target for ~/.config/obsidian/
├── version.txt                     # Optional: user-pinned version
└── cached_version.txt              # Tracks currently cached .deb version
```

## Execution Flow

### On Every Boot

1. Create directories: `$SAVE_DIR/{packages,config}`
2. Determine target version:
   - If `version.txt` exists: use pinned version
   - Else if network available: query GitHub API for latest
   - Else: use cached version
3. Download if needed (target != cached AND network available)
4. Install from cache: `sudo dpkg --force-depends -i obsidian_*.deb`
5. Setup config symlink: `~/.config/obsidian` → `$SAVE_DIR/config/`

### First-Run (No Cache)

- Zenity progress dialog with stages
- Download from GitHub releases
- Cache .deb and record version
- Install and setup symlinks

### Offline Boot (Cache Exists)

- Skip version check and download
- Install from cache silently
- Fast path with no network dependency

## Version Fetching

GitHub API endpoint (no auth, 60 req/hr limit):
```
https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest
```

Download URL pattern:
```
https://github.com/obsidianmd/obsidian-releases/releases/download/v{VERSION}/obsidian_{VERSION}_amd64.deb
```

## Error Handling

| Scenario | Behavior |
|----------|----------|
| GitHub API failure | Fall back to cached version |
| Download failure | Notify user, preserve existing cache |
| No cache + no network | Notify user with manual instructions |
| dpkg failure | Run `apt-get install -f` as fallback |

## User Instructions

1. Add `OBSIDIAN.sh` to `ENABLED_MODULES`
2. Reboot with network for automatic download
3. Launch Obsidian, select/create vault on `/arcHIVE`
4. Optional: Pin version via `$SAVE_DIR/version.txt`
