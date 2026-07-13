#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
disk_image="${1:?Usage: verify-dmg.sh <dmg path>}"
mountpoint="$(mktemp -d)"
attached=false

cleanup() {
    if [[ "$attached" == true ]]; then
        hdiutil detach -quiet "$mountpoint"
    fi
    rmdir "$mountpoint"
}
trap cleanup EXIT

hdiutil verify -quiet "$disk_image"
codesign --verify --verbose=2 "$disk_image"
hdiutil attach -quiet -noverify -nobrowse -readonly -mountpoint "$mountpoint" "$disk_image"
attached=true

test -d "$mountpoint/Kivra.app"
test -L "$mountpoint/Applications"
test "$(readlink "$mountpoint/Applications")" = "/Applications"
"$root/Scripts/verify-app.sh" "$mountpoint/Kivra.app"
