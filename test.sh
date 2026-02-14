#!/bin/bash
set -euo pipefail

# Build the test bundle, then run it directly with xctest.
# This avoids the "Pseudo Terminal Setup Error" that xcodebuild test
# hits in sandboxed environments (e.g. Claude Code, some CI systems).

xcodebuild build-for-testing \
  -project Freeboard.xcodeproj \
  -scheme Freeboard \
  -destination 'platform=macOS' \
  -quiet

BUNDLE=$(find ~/Library/Developer/Xcode/DerivedData/Freeboard-*/Build/Products/Debug \
  -name "FreeboardTests.xctest" -maxdepth 1 | head -1)

if [ -z "$BUNDLE" ]; then
  echo "Error: FreeboardTests.xctest not found in DerivedData" >&2
  exit 1
fi

xcrun xctest "$BUNDLE"
