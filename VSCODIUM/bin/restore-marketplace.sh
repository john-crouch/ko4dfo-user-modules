#!/bin/bash
# Restore Open VSX marketplace (default for VSCodium)

sudo tee /usr/share/codium/resources/app/product.json > /dev/null << 'OPENVSX'
{
  "extensionsGallery": {
    "serviceUrl": "https://open-vsx.org/vscode/gallery",
    "itemUrl": "https://open-vsx.org/vscode/item"
  }
}
OPENVSX

echo "Restored Open VSX marketplace. Restart VSCodium."
