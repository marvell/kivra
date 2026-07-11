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

1. Download `Kivra-<version>-macOS-arm64.zip` from the [latest release](https://github.com/marvell/kivra/releases/latest).
2. Open the downloaded ZIP file.
3. Drag `Kivra.app` to `Applications`.
4. Open Kivra from Applications.
5. Grant access in **System Settings → Privacy & Security → Accessibility**.

To update, replace Kivra in Applications with the app from a newer release. To uninstall, quit Kivra and move it from Applications to the Bin.

Kivra is signed and notarized by its publisher. It is distributed through GitHub Releases, not the Mac App Store.

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

## Setup

1. Grant Kivra access in **System Settings → Privacy & Security → Accessibility**.
2. Open the Kivra status bar menu.
3. Select a system keyboard input source for **Left Shift**.
4. Select a system keyboard input source for **Right Shift**.
5. Optionally change the tap threshold (250 ms by default).

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

Create and push a semantic-version tag to publish a release:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The release workflow tests Kivra, builds and signs the Apple Silicon app, submits it for notarization, and uploads a ZIP archive with its SHA-256 checksum.
