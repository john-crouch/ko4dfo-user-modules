#!/bin/bash
# ABOUTME: Copies HANDOVER scripts to the parent directory if missing or outdated

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="${SCRIPT_DIR}/.."
HANDOVER_DIR="${SCRIPT_DIR}/HANDOVER"

# Ensure HANDOVER directory exists
if [[ ! -d "${HANDOVER_DIR}" ]]; then
    echo "Error: HANDOVER directory not found in ${SCRIPT_DIR}"
    exit 1
fi

# Make HANDOVER scripts executable
chmod +x "${HANDOVER_DIR}"/*.sh

# Check if scripts need updating and copy if necessary
UPDATED=0
for script in "${HANDOVER_DIR}"/*.sh; do
    if [[ -f "$script" ]]; then
        script_name="$(basename "$script")"
        target="${PARENT_DIR}/${script_name}"

        # Check if target doesn't exist or differs from source
        if [[ ! -f "$target" ]] || ! diff -q "$script" "$target" &>/dev/null; then
            cp "$script" "$target"
            chmod +x "$target"
            echo "Updated: ${script_name}"
            UPDATED=1
        fi
    fi
done

if [[ $UPDATED -eq 1 ]]; then
    echo ""
    echo "HANDOVER scripts updated in ${PARENT_DIR}"
else
    echo "HANDOVER scripts are up to date."
fi
