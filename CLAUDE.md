# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal user modules for KO4DFO's arcOS Live Linux station setup. These are modular shell scripts that execute during `station-setup` to configure an amateur radio workstation. The system uses an overlay filesystem where `/etc` and `/usr` changes don't persist across reboots, but `/arcHIVE` (exFAT) does persist.

## Key Constraints

- **Overlay filesystem**: Changes to `/etc`, `/usr` don't survive reboot - modules must recreate them each boot
- **exFAT on /arcHIVE**: No symlinks ON the filesystem, no Unix permissions, no colons in filenames. Symlinks TO exFAT from Linux filesystem work fine.
- **dpkg persistence issue**: dpkg database may think packages are installed but files are missing after reboot
- **No apt-get install**: Never use `apt-get install` or `apt install` in modules that run at boot. It's slow and can trigger installation of hundreds of unrelated packages. Instead, cache `.deb` files in `$SAVE_DIR/packages/` and use `dpkg --force-depends -i` to install them.

## Commands

```bash
# Run test suite
./tests.sh

# Run a specific module manually
./MODULE-NAME/MODULE-NAME.sh

# Setup handover scripts (copies to parent USER directory)
./setup-handover.sh
```

## Module Structure

Each module follows this pattern:
```bash
MODULE="MODULE-NAME"
source $HOME/.station-info
ARCOS_DATA=/arcHIVE
MODULE_DIR=$ARCOS_DATA/QRV/$MYCALL/arcos-linux-modules/USER/ko4dfo-user-modules/$MODULE
LOGFILE=$MODULE_DIR/$MODULE.log
SAVE_DIR=$ARCOS_DATA/QRV/$MYCALL/SAVED/$MODULE

module_commands () {
    # Module logic here
}
module_commands > $LOGFILE 2>&1 || notify-send --icon=error "$MODULE" "$MODULE module failed!"
```

- `$MYCALL` comes from `~/.station-info` (e.g., KO4DFO)
- Persistent data goes in `$SAVE_DIR` under `/arcHIVE/QRV/$MYCALL/SAVED/`
- Scripts install to `/opt/arcOS/bin/`, desktop files to `~/.local/share/applications/`
- Use tarballs (not cp/rsync) when caching directory trees to exFAT to preserve symlinks

## Module Enablement

`ENABLED_MODULES` controls which modules run and their order. Scripts are `MODULE-NAME.sh`, not `setup.sh`.

## Current Modules

- **CLAUDE-CODE**: Restores nodejs/Claude Code from cached tarballs, symlinks `~/.claude` to persistent storage
- **SET-MINT-THEME**: Modifies `/etc/profile.d/arcos-customization.sh` to use saved theme values instead of defaults
- **UPDATE-MODULES**: Custom module updater with branch selection, preserves local modifications, smart notifications
- **VSCODIUM**: Symlinks config and extensions to persistent storage
- **PAT-WEBVIEW**: PAT Winlink web interface launcher

## Testing

The test framework in `tests.sh` provides assertions: `assert_file_exists`, `assert_dir_exists`, `assert_executable`, `assert_symlink`, `assert_symlink_target`, `assert_command_exists`, `assert_contains`, `assert_gsetting`.
