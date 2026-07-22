# Kivra

Switch between two macOS keyboard layouts with a quick tap of Shift.

- Tap **Left Shift** for one layout.
- Tap **Right Shift** for the other.
- Keep using Shift normally for capital letters and keyboard shortcuts.

Kivra is made for people who type in two languages and want each layout to
have its own key. There is no need to cycle through input sources or remember
which layout is currently active.

## Requirements

- A Mac with Apple silicon
- macOS 15 or later
- Two keyboard layouts enabled in macOS

## Install Kivra

1. [Download the latest release](https://github.com/marvell/kivra/releases/latest)
   and choose the file named `Kivra-<version>-macOS-arm64.dmg`.
2. Open the downloaded disk image.
3. Drag **Kivra** into the **Applications** folder.
4. Open Kivra from Applications.

Kivra is signed and notarized by its publisher. It is distributed through
GitHub Releases rather than the Mac App Store.

## Set it up

The welcome guide takes care of the initial setup:

1. Grant **Accessibility** access. Kivra needs this permission to recognize
   Shift taps; it does not read or store what you type.
2. Choose a keyboard layout for **Left Shift** and another for **Right Shift**.
3. Choose whether Kivra should open automatically when you log in.
4. Select **Start Kivra**.

Kivra then lives behind the keyboard icon in the macOS menu bar. Open that
menu at any time to pause Kivra, change its settings, check for updates, or
quit the app.

If fewer than two layouts appear, add another one in **System Settings →
Keyboard → Text Input → Edit**, then return to Kivra.

## How a Shift tap works

A quick press and release switches to the layout assigned to that Shift key.
Kivra does not switch layouts when Shift is used together with another key, or
when both Shift keys overlap, so normal typing and shortcuts keep working as
expected. It also leaves the original keyboard events unchanged.

The default tap limit is 250 ms. If quick taps are not being recognized—or a
longer press switches layouts too easily—open **Settings…** from the menu bar
and adjust **Tap threshold**.

## Privacy and permissions

Kivra uses Accessibility access only to recognize Shift taps. It does not read
or store the text you type.

macOS temporarily blocks keyboard-event monitoring while Secure Event Input is
active, which can happen in some password fields. Kivra cannot switch layouts
during that time and resumes when macOS allows monitoring again.

## Updates and uninstalling

Kivra checks for updates daily. You can also choose **Check for Updates…** from
the menu bar. Updates are downloaded from GitHub Releases, verified, and
installed after you confirm them.

To uninstall Kivra, quit it and move **Kivra** from Applications to the Bin.

<details>
<summary><strong>For developers and maintainers</strong></summary>

### Develop

Use [Task](https://taskfile.dev/) for common development work:

```bash
task run
task build
task test
task format
task lint
task install-dev
```

You can also run the app directly from the project directory:

```bash
swift run
```

Or build and run the release binary:

```bash
swift build -c release
.build/release/Kivra
```

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

### Test

```bash
task lint
task test
```

### Release

Maintainers need an Apple Developer account with a Developer ID Application
certificate. Configure these GitHub Actions secrets:

- `APPLE_CERTIFICATE_BASE64`, the base64-encoded `.p12` Developer ID
  Application certificate.
- `APPLE_CERTIFICATE_PASSWORD`, the certificate export password.
- `APPLE_ID`, the Apple Account used for notarization.
- `APPLE_APP_SPECIFIC_PASSWORD`, an app-specific password for that account.
- `APPLE_TEAM_ID`, the Apple Developer team ID.
- `SPARKLE_PRIVATE_KEY`, the base64-encoded private Ed25519 key exported by
  Sparkle's `generate_keys` tool. Keep an offline backup and never commit it.

GitHub Pages must use **GitHub Actions** as its publishing source. The release
workflow publishes the signed Sparkle feed at
`https://marvell.github.io/kivra/appcast.xml` only after the corresponding
GitHub Release assets are downloadable.

Create and push a semantic-version tag to publish a release:

```bash
git tag v0.1.1
git push origin v0.1.1
```

The release workflow tests Kivra, signs the app and its embedded Sparkle
helpers, notarizes the app and disk image, publishes the DMG with its SHA-256
checksum, and deploys a signed Sparkle appcast. Published releases are treated
as immutable; rerunning a completed release only republishes its existing
appcast.

The first Sparkle-enabled release still needs to be installed manually by
users of `v0.1.0`. Releases after that can update in place.

Kivra uses the [Sparkle](https://sparkle-project.org/) update framework. Its
license is included in the application bundle.

</details>
