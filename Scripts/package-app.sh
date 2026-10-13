#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${VERSION:-0.1.0}"
build_number="${BUILD_NUMBER:-1}"
architecture="${ARCHITECTURE:-arm64}"
output_directory="${OUTPUT_DIRECTORY:-$root/dist}"
build_variant="${BUILD_VARIANT:-stable}"

case "$build_variant" in
    stable)
        app_name="Kivra"
        bundle_identifier="com.zemliakov.kivra"
        ;;
    dev)
        app_name="Kivra Dev"
        bundle_identifier="com.zemliakov.kivra.dev"
        ;;
    *)
        echo "Unsupported build variant: $build_variant (expected stable or dev)" >&2
        exit 1
        ;;
esac

app="$output_directory/$app_name.app"
sparkle="$app/Contents/Frameworks/Sparkle.framework"
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
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/ThirdPartyLicenses" "$app/Contents/Frameworks"
ditto "$binary_directory/Kivra" "$app/Contents/MacOS/Kivra"
ditto "$binary_directory/Sparkle.framework" "$sparkle"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"
cp "$root/.build/checkouts/Sparkle/LICENSE" "$app/Contents/Resources/ThirdPartyLicenses/Sparkle.txt"

# Kivra is not sandboxed, so Sparkle's sandbox-only XPC services are unnecessary.
# Removing them reduces both the attack surface and the number of nested bundles
# that must be signed manually by this non-Xcode packaging workflow.
rm -rf "$sparkle/Versions/Current/XPCServices" "$sparkle/XPCServices"

swift "$root/Scripts/create-icon.swift" "$iconset/AppIcon.iconset" "$build_variant"
iconutil --convert icns "$iconset/AppIcon.iconset" --output "$app/Contents/Resources/AppIcon.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $app_name" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $app_name" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_identifier" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :KivraBuildVariant $build_variant" "$app/Contents/Info.plist"

if [[ "$build_variant" == "dev" ]]; then
    # Dev is a parallel local installation, not a Sparkle release channel.
    # Keep the linked framework, but remove its production configuration.
    for key in \
        SUAutomaticallyUpdate \
        SUEnableAutomaticChecks \
        SUFeedURL \
        SUPublicEDKey \
        SURequireSignedFeed \
        SUVerifyUpdateBeforeExtraction
    do
        /usr/libexec/PlistBuddy -c "Delete :$key" "$app/Contents/Info.plist"
    done
fi

identity="${SIGNING_IDENTITY:--}"
sign_arguments=(--force --sign "$identity")
if [[ "$identity" != "-" ]]; then
    sign_arguments+=(--options runtime)
    case "${SIGNING_TIMESTAMP:-auto}" in
        always|true)
            sign_arguments+=(--timestamp)
            ;;
        never|false)
            ;;
        auto)
            if [[ "$identity" == *"Developer ID Application"* ]]; then
                sign_arguments+=(--timestamp)
            fi
            ;;
        *)
            echo "Unsupported SIGNING_TIMESTAMP value (expected auto, always, or never)" >&2
            exit 1
            ;;
    esac
fi

# Sign nested code from the inside out. Do not use --deep for signing Sparkle;
# its components have different signing requirements.
codesign "${sign_arguments[@]}" "$sparkle/Autoupdate"
codesign "${sign_arguments[@]}" "$sparkle/Updater.app"
codesign "${sign_arguments[@]}" "$sparkle"
codesign "${sign_arguments[@]}" "$app"

echo "$app"
