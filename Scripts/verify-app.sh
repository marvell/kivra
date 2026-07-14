#!/usr/bin/env bash
set -euo pipefail

app="${1:?Usage: verify-app.sh <app path>}"
binary="$app/Contents/MacOS/Kivra"
sparkle="$app/Contents/Frameworks/Sparkle.framework"

plutil -lint "$app/Contents/Info.plist"
short_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")"
build_variant="$(/usr/libexec/PlistBuddy -c 'Print :KivraBuildVariant' "$app/Contents/Info.plist")"
[[ "$short_version" =~ ^[0-9]+(\.[0-9]+){2}(-[0-9A-Za-z.-]+)?$ ]]
[[ "$build_number" =~ ^[0-9]+$ ]]
(( build_number > 0 ))

case "$build_variant" in
    stable)
        test "$(basename "$app")" = "Kivra.app"
        test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$app/Contents/Info.plist")" = "Kivra"
        test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$app/Contents/Info.plist")" = "Kivra"
        test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" = "com.zemliakov.kivra"
        test "$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$app/Contents/Info.plist")" = "https://marvell.github.io/kivra/appcast.xml"
        test "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$app/Contents/Info.plist")" = "37V+opO1CeNWInqnwvCW62qZ7u1F1+uA13yBd1vx1uk="
        test "$(/usr/libexec/PlistBuddy -c 'Print :SUEnableAutomaticChecks' "$app/Contents/Info.plist")" = "true"
        test "$(/usr/libexec/PlistBuddy -c 'Print :SUAutomaticallyUpdate' "$app/Contents/Info.plist")" = "false"
        test "$(/usr/libexec/PlistBuddy -c 'Print :SURequireSignedFeed' "$app/Contents/Info.plist")" = "true"
        test "$(/usr/libexec/PlistBuddy -c 'Print :SUVerifyUpdateBeforeExtraction' "$app/Contents/Info.plist")" = "true"
        ;;
    dev)
        test "$(basename "$app")" = "Kivra Dev.app"
        test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$app/Contents/Info.plist")" = "Kivra Dev"
        test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$app/Contents/Info.plist")" = "Kivra Dev"
        test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" = "com.zemliakov.kivra.dev"
        for key in \
            SUAutomaticallyUpdate \
            SUEnableAutomaticChecks \
            SUFeedURL \
            SUPublicEDKey \
            SURequireSignedFeed \
            SUVerifyUpdateBeforeExtraction
        do
            ! /usr/libexec/PlistBuddy -c "Print :$key" "$app/Contents/Info.plist" >/dev/null 2>&1
        done
        ;;
    *)
        echo "Unsupported KivraBuildVariant: $build_variant" >&2
        exit 1
        ;;
esac
test -x "$binary"
test -d "$sparkle"
test -s "$app/Contents/Resources/ThirdPartyLicenses/Sparkle.txt"
test -x "$sparkle/Autoupdate"
test -x "$sparkle/Updater.app/Contents/MacOS/Updater"
test ! -e "$sparkle/Versions/Current/XPCServices"
test ! -e "$sparkle/XPCServices"

lipo -info "$binary"
otool -L "$binary" | grep -Fq "@rpath/Sparkle.framework/Versions/B/Sparkle"
otool -l "$binary" | grep -A2 "LC_RPATH" | grep -Fq "@executable_path/../Frameworks"

codesign --verify --deep --strict --verbose=2 "$app"
