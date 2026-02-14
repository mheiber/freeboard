#!/bin/bash
set -e

# Downloads TextMate grammar support files for Monaco Editor.
# Uses unpkg.com CDN to fetch pre-built UMD bundles (no npm/esbuild needed).
#
# Files produced:
#   vscode-textmate.js       - TextMate grammar engine (UMD, global: vscodetextmate)
#   vscode-oniguruma.js      - Oniguruma regex engine (UMD, global: onig)
#   onig.wasm                - Oniguruma WASM binary
#   markdown.tmLanguage.json - VS Code's markdown TextMate grammar (MIT)

RESOURCES="$(cd "$(dirname "$0")/../Freeboard/Resources/MonacoEditor" && pwd)"

TEXTMATE_VERSION="9.1.0"
ONIGURUMA_VERSION="2.0.1"

echo "Downloading vscode-textmate v${TEXTMATE_VERSION}..."
curl -sL "https://unpkg.com/vscode-textmate@${TEXTMATE_VERSION}/release/main.js" \
  -o "$RESOURCES/vscode-textmate.js"

echo "Downloading vscode-oniguruma v${ONIGURUMA_VERSION}..."
curl -sL "https://unpkg.com/vscode-oniguruma@${ONIGURUMA_VERSION}/release/main.js" \
  -o "$RESOURCES/vscode-oniguruma.js"

echo "Downloading onig.wasm..."
curl -sL "https://unpkg.com/vscode-oniguruma@${ONIGURUMA_VERSION}/release/onig.wasm" \
  -o "$RESOURCES/onig.wasm"

echo "Downloading markdown.tmLanguage.json..."
curl -sL "https://raw.githubusercontent.com/microsoft/vscode/main/extensions/markdown-basics/syntaxes/markdown.tmLanguage.json" \
  -o "$RESOURCES/markdown.tmLanguage.json"

echo "Done. Files copied to $RESOURCES"
