#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${VERSION:-0.1.0}"
build_number="${BUILD_NUMBER:-1}"
architecture="${ARCHITECTURE:-arm64}"
output_directory="${OUTPUT_DIRECTORY:-$root/dist}"
app="$output_directory/Kivra.app"
iconset="$(mktemp -d)"

cleanup() {
    rm -rf "$iconset"
}
trap cleanup EXIT

case "$architecture" in
    arm64) ;;
    *)
        echo "Unsupported architecture: $architecture" >&2
        exit 1
        ;;
esac

binary_directory="$(swift build --package-path "$root" -c release --arch "$architecture" --show-bin-path)"
swift build --package-path "$root" -c release --arch "$architecture"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
ditto "$binary_directory/Kivra" "$app/Contents/MacOS/Kivra"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"

swift "$root/Scripts/create-icon.swift" "$iconset/AppIcon.iconset"
iconutil --convert icns "$iconset/AppIcon.iconset" --output "$app/Contents/Resources/AppIcon.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$app/Contents/Info.plist"

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$app"
else
    codesign --force --sign - "$app"
fi

echo "$app"
