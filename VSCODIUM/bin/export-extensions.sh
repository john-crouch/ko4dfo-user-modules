#!/bin/bash

# Export currently installed VSCodium extensions to a list

MODULE_DIR="$1"

if [ -z "$MODULE_DIR" ]; then
    echo "Usage: $0 <MODULE_DIR>"
    exit 1
fi

EXTENSION_LIST="$MODULE_DIR/config/extensions.txt"

echo "Exporting VSCodium extensions to $EXTENSION_LIST..."

codium --list-extensions > "$EXTENSION_LIST"

if [ -s "$EXTENSION_LIST" ]; then
    echo "Successfully exported $(wc -l < "$EXTENSION_LIST") extensions"
    cat "$EXTENSION_LIST"
else
    echo "No extensions found or export failed"
fi
