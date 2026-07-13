#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
archives="${1:?Usage: generate-appcast.sh <archives directory> <release tag>}"
tag="${2:?Usage: generate-appcast.sh <archives directory> <release tag>}"
repository="${GITHUB_REPOSITORY:-marvell/kivra}"
tools="${SPARKLE_TOOLS_DIRECTORY:-$root/.build/artifacts/sparkle/Sparkle/bin}"
private_key="${SPARKLE_PRIVATE_KEY:?SPARKLE_PRIVATE_KEY must contain the base64-encoded Sparkle private key}"

test -x "$tools/generate_appcast"
test -d "$archives"

download_prefix="https://github.com/$repository/releases/download/$tag/"
release_url="https://github.com/$repository/releases/tag/$tag"
arguments=(
    --ed-key-file -
    --download-url-prefix "$download_prefix"
    --link "$release_url"
    --maximum-versions 10
    --maximum-deltas 0
    --embed-release-notes
    -o "$archives/appcast.xml"
)
if [[ -n "${SPARKLE_CHANNEL:-}" ]]; then
    arguments+=(--channel "$SPARKLE_CHANNEL")
fi

if [[ -f "$archives/appcast.xml" ]]; then
    printf '%s' "$private_key" | "$tools/sign_update" \
        --verify \
        --ed-key-file - \
        "$archives/appcast.xml"
fi

printf '%s' "$private_key" | "$tools/generate_appcast" \
    "${arguments[@]}" \
    "$archives"

xmllint --noout "$archives/appcast.xml"
grep -Fq "$download_prefix" "$archives/appcast.xml"
grep -Fq "sparkle:edSignature" "$archives/appcast.xml"
grep -Fq "sparkle-signatures:" "$archives/appcast.xml"
printf '%s' "$private_key" | "$tools/sign_update" \
    --verify \
    --ed-key-file - \
    "$archives/appcast.xml"
