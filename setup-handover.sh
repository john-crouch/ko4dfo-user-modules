#!/bin/bash
# ABOUTME: Copies HANDOVER scripts to the parent directory

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

# Copy HANDOVER scripts to parent directory
for script in "${HANDOVER_DIR}"/*.sh; do
    if [[ -f "$script" ]]; then
        script_name="$(basename "$script")"
        target="${PARENT_DIR}/${script_name}"

        # Copy file
        cp "$script" "$target"
        chmod +x "$target"
        echo "Copied: ${script_name} -> ${PARENT_DIR}"
    fi
done

echo ""
echo "HANDOVER scripts successfully copied to ${PARENT_DIR}"
echo ""
echo "Edit ENABLED_MODULES to control which modules run."
