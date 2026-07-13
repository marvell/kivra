#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="${1:?Usage: package-dmg.sh <app path> [output path]}"
version="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")}"
output="${2:-$root/dist/Kivra-$version-macOS-arm64.dmg}"
staging="$(mktemp -d)"

cleanup() {
    rm -rf "$staging"
}
trap cleanup EXIT

test -d "$app"
mkdir -p "$(dirname "$output")"
ditto "$app" "$staging/Kivra.app"
ln -s /Applications "$staging/Applications"

hdiutil create \
    -quiet \
    -volname "Kivra" \
    -srcfolder "$staging" \
    -format UDZO \
    -ov \
    "$output"

identity="${SIGNING_IDENTITY:--}"
sign_arguments=(--force --sign "$identity")
if [[ "$identity" != "-" ]]; then
    sign_arguments+=(--timestamp)
fi
codesign "${sign_arguments[@]}" "$output"

echo "$output"
