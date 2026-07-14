#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install_directory="${INSTALL_DIRECTORY:-/Applications}"
destination="$install_directory/Kivra Dev.app"
source_app="$root/dist/Kivra Dev.app"
base_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$root/Resources/Info.plist")"
version="${VERSION:-$base_version-dev}"
build_number="${BUILD_NUMBER:-$(git -C "$root" rev-list --count HEAD)}"

if pgrep -f -x "$destination/Contents/MacOS/Kivra" >/dev/null; then
    echo "Quit Kivra Dev before reinstalling it." >&2
    exit 1
fi

if [[ -z "${SIGNING_IDENTITY+x}" ]]; then
    identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
    signing_identity="$(awk -F '"' '/Apple Development:/ { print $2; exit }' <<<"$identities")"
    if [[ -z "$signing_identity" ]]; then
        signing_identity="$(awk -F '"' '/Developer ID Application:/ { print $2; exit }' <<<"$identities")"
    fi

    if [[ -n "$signing_identity" ]]; then
        export SIGNING_IDENTITY="$signing_identity"
        echo "Signing Kivra Dev with $signing_identity"
    else
        echo "No development signing identity found; using an ad-hoc signature." >&2
        echo "Accessibility permission may need to be granted again after rebuilds." >&2
    fi
fi

BUILD_VARIANT=dev \
VERSION="$version" \
BUILD_NUMBER="$build_number" \
OUTPUT_DIRECTORY="$root/dist" \
"$root/Scripts/package-app.sh"

"$root/Scripts/verify-app.sh" "$source_app"

mkdir -p "$install_directory"
staging_directory="$(mktemp -d "$install_directory/.kivra-dev-install.XXXXXX")"
staged_app="$staging_directory/Kivra Dev.app"
previous_app="$staging_directory/Kivra Dev.previous.app"

cleanup() {
    if [[ -e "$previous_app" && ! -e "$destination" ]]; then
        mv "$previous_app" "$destination"
    fi
    rm -rf "$staging_directory"
}
trap cleanup EXIT

ditto "$source_app" "$staged_app"

if [[ -e "$destination" ]]; then
    existing_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/Contents/Info.plist" 2>/dev/null || true)"
    if [[ "$existing_identifier" != "com.zemliakov.kivra.dev" ]]; then
        echo "Refusing to replace $destination because its bundle identifier is $existing_identifier" >&2
        exit 1
    fi
    mv "$destination" "$previous_app"
fi

if ! mv "$staged_app" "$destination"; then
    echo "Could not install $destination; restoring the previous version." >&2
    exit 1
fi

if ! "$root/Scripts/verify-app.sh" "$destination"; then
    echo "Installed bundle failed verification; restoring the previous version." >&2
    rm -rf "$destination"
    exit 1
fi

echo "Installed $destination"
