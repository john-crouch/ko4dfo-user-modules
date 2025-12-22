#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: $0 publisher.extension"
    echo "Example: $0 GitHub.copilot"
    exit 1
fi
EXTENSION="$1"
PUBLISHER=$(echo $EXTENSION | cut -d'.' -f1)
NAME=$(echo $EXTENSION | cut -d'.' -f2-)
URL="https://${PUBLISHER}.gallery.vsassets.io/_apis/public/gallery/publisher/${PUBLISHER}/extension/${NAME}/latest/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage"
OUTPUT_DIR="$(cd "$(dirname "$0")/../config" && pwd)"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="$OUTPUT_DIR/${EXTENSION}.vsix"
echo "Downloading $EXTENSION..."
wget -O "$OUTPUT_FILE" "$URL" 2>&1 | tail -5
if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
    echo "Success: $OUTPUT_FILE"
else
    echo "Failed"
    rm -f "$OUTPUT_FILE"
    exit 1
fi
