#!/usr/bin/env bash
set -euo pipefail

app="${1:?Usage: verify-app.sh <app path>}"

plutil -lint "$app/Contents/Info.plist"
lipo -info "$app/Contents/MacOS/Kivra"
codesign --verify --deep --strict --verbose=2 "$app"
