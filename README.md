# ko4dfo-user-modules

Personal user modules for KO4DFO's arcos-linux station setup.

## Overview

This repository contains modular shell scripts managed by the arcos-linux `station-setup` framework. The module system enables organized, git-tracked configuration scripts that execute during system initialization.

## Module Execution Phases

The framework supports two execution phases during `station-setup`:

- **Pre-restart phase**: Scripts ending in `.pre.sh` run before the desktop environment restarts
- **Post-restart phase**: Standard `.sh` scripts execute after the Cinnamon environment reloads

Execution order follows the `ENABLED_MODULES` file (top-down), with `.pre.sh` variants always running before standard scripts regardless of file order.

## Directory Structure

```
ko4dfo-user-modules/
├── MODULE-NAME/          # Module-specific scripts and configs
│   ├── setup.sh         # Post-restart script
│   └── setup.pre.sh     # Pre-restart script (optional)
├── HANDOVER/            # Handover scripts (symlinked to top-level)
├── ENABLED_MODULES      # Controls which modules load and their order
├── setup-handover.sh    # Creates symlinks for HANDOVER scripts
└── README.md
```

## Installation

1. Clone this repository into `/arcHIVE/QRV/KO4DFO/arcos-linux-modules/USER`:
   ```bash
   cd /arcHIVE/QRV/KO4DFO/arcos-linux-modules
   git clone <repository-url> USER/ko4dfo-user-modules
   ```

2. Create symlinks for HANDOVER scripts:
   ```bash
   cd USER/ko4dfo-user-modules
   ./setup-handover.sh
   ```

   This symlinks `HANDOVER/*.sh` files to the top-level directory, ensuring:
   - Files only exist in one place (in the repo)
   - Updates to the repo automatically apply
   - No risk of git seeing them as deleted

3. Edit `ENABLED_MODULES` to control module execution order:
   ```bash
   # List modules one per line, top-down execution order
   MODULE-NAME-1
   MODULE-NAME-2
   ```

## Module Architecture

**Key principle**: Only `HANDOVER` module scripts are symlinked to the top-level directory. All other modules remain organized within their respective subdirectories, keeping the repository structure clean and maintainable.

## Creating New Modules

1. Create a new directory for your module: `mkdir MODULE-NAME`
2. Add scripts: `MODULE-NAME/setup.sh` and optionally `MODULE-NAME/setup.pre.sh`
3. Make scripts executable: `chmod +x MODULE-NAME/*.sh`
4. Add module name to `ENABLED_MODULES`
5. Commit and push changes

## License

Personal configuration repository for KO4DFO.
