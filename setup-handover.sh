#!/bin/bash
# ABOUTME: Creates symlinks for HANDOVER scripts in the parent directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="${SCRIPT_DIR}/.."

# Ensure HANDOVER directory exists
if [[ ! -d "${SCRIPT_DIR}/HANDOVER" ]]; then
    echo "Error: HANDOVER directory not found in ${SCRIPT_DIR}"
    exit 1
fi

# Create symlinks for all .sh files in HANDOVER/
for script in "${SCRIPT_DIR}/HANDOVER"/*.sh; do
    if [[ -f "$script" ]]; then
        script_name="$(basename "$script")"
        target="${PARENT_DIR}/${script_name}"

        # Remove existing symlink or file
        if [[ -L "$target" ]]; then
            echo "Removing existing symlink: ${target}"
            rm "$target"
        elif [[ -f "$target" ]]; then
            echo "Warning: Regular file exists at ${target}, removing..."
            rm "$target"
        fi

        # Create symlink
        ln -sf "${script}" "${target}"
        echo "Created symlink: ${target} -> ${script}"
    fi
done

echo "HANDOVER scripts successfully symlinked to ${PARENT_DIR}"
