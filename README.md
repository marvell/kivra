# Kivra

Kivra is a macOS status bar app that selects a keyboard input source with a short Shift tap:

- Left Shift selects the first configured source.
- Right Shift selects the second configured source.

It does not alter the original keyboard events. A Shift tap switches only when it is released within the selected threshold and no other key or Shift was pressed in between.

## Requirements

- macOS 15 or later
- Swift 6 / Xcode Command Line Tools
- Accessibility permission

## Run

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
