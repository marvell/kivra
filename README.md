# Kivra

Kivra is a macOS status bar app that selects a keyboard input source with a short Shift tap:

- Left Shift selects the first configured source.
- Right Shift selects the second configured source.

It does not alter the original keyboard events. A Shift tap switches only when it is released within the selected threshold and no other key or Shift was pressed in between.

Kivra is a lightweight, high-performance native app for one of macOS's oldest typing frustrations: switching keyboard layouts without breaking your flow. It is designed for people who type fast and need layout switching to feel immediate, simple, and dependable.

## Requirements

- Apple Silicon Mac running macOS 15 or later
- Accessibility permission

## Install

1. Download `Kivra-<version>-macOS-arm64.dmg` from the [latest release](https://github.com/marvell/kivra/releases/latest).
2. Open the downloaded disk image.
3. Drag `Kivra.app` to `Applications`.
4. Open Kivra from Applications.
5. Follow the welcome setup to grant Accessibility access and choose a layout for each Shift key.

Kivra checks for updates daily. You can also use **Check for Updates…** from the status bar menu. Updates are downloaded from GitHub Releases, verified, installed in place, and relaunched after confirmation. To uninstall, quit Kivra and move it from Applications to the Bin.

Kivra is signed and notarized by its publisher. It is distributed through GitHub Releases, not the Mac App Store.
It uses the [Sparkle](https://sparkle-project.org/) update framework; its license is included in the application bundle.

## Develop

From the project directory:

```bash
swift run
```

Or build and run the release binary:

```bash
swift build -c release
.build/release/Kivra
```

The keyboard icon appears in the status bar.

### Local development installation

Build and install the parallel development app:

```bash
Scripts/install-dev.sh
```

This creates `/Applications/Kivra Dev.app` with bundle identifier
`com.zemliakov.kivra.dev`. It has separate preferences and a separate
Accessibility permission from the stable `Kivra.app`. Its production Sparkle
configuration is removed, so it cannot update itself to a published release.

Kivra Dev is marked with a `DEV` badge in its app and status bar icons. Stable
and Dev may remain installed together, but only one can run at a time because
both monitor the same global Shift events. Quit the running variant before
opening the other one.

The installer uses an available Apple Development signing identity, falling
back to Developer ID Application and then to an ad-hoc signature. Keeping the
same Apple signing identity lets macOS preserve Accessibility approval more
reliably between rebuilds. You can select one explicitly:

```bash
SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)" Scripts/install-dev.sh
```

To build without installing:

```bash
BUILD_VARIANT=dev Scripts/package-app.sh
```

Set `INSTALL_DIRECTORY` if you prefer another fixed location, such as
`$HOME/Applications`. Do not move the app between rebuilds if you want macOS to
retain its privacy permission consistently.

## Setup

Kivra opens a guided setup on first launch. It explains and requests Accessibility access, then lets you choose a system keyboard input source for **Left Shift** and **Right Shift**. You can reopen the guide later with **Settings…** from the status bar menu.

The tap threshold is 250 ms by default and can be changed from the guided setup.

Kivra only shows enabled, selectable input sources from macOS settings.

## Limits

macOS can prevent keyboard-event monitoring while Secure Event Input is enabled, such as in some password fields. Kivra cannot operate during that time.

macOS and the focused application control the final input-source application timing. Kivra requests the source selection directly when Shift is released to minimize delay.

## Test

```bash
swift test
```

## Release

Maintainers need an Apple Developer account with a Developer ID Application certificate. Configure these GitHub Actions secrets:

- `APPLE_CERTIFICATE_BASE64`, the base64-encoded `.p12` Developer ID Application certificate.
- `APPLE_CERTIFICATE_PASSWORD`, the certificate export password.
- `APPLE_ID`, the Apple Account used for notarization.
- `APPLE_APP_SPECIFIC_PASSWORD`, an app-specific password for that account.
- `APPLE_TEAM_ID`, the Apple Developer team ID.
- `SPARKLE_PRIVATE_KEY`, the base64-encoded private Ed25519 key exported by Sparkle's `generate_keys` tool. Keep an offline backup and never commit it.

GitHub Pages must use **GitHub Actions** as its publishing source. The release workflow publishes the signed Sparkle feed at `https://marvell.github.io/kivra/appcast.xml` only after the corresponding GitHub Release assets are downloadable.

Create and push a semantic-version tag to publish a release:

```bash
git tag v0.1.1
git push origin v0.1.1
```

The release workflow tests Kivra, signs the app and its embedded Sparkle helpers, notarizes the app and disk image, publishes the DMG with its SHA-256 checksum, and deploys a signed Sparkle appcast. Published releases are treated as immutable; rerunning a completed release only republishes its existing appcast.

The first Sparkle-enabled release still needs to be installed manually by users of `v0.1.0`. Releases after that can update in place.
