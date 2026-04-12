# Clipo

Clipo is a lightweight clipboard manager for macOS. It lives in the menu bar, keeps a searchable clipboard history, previews images inline, and lets you paste previous items back into the app you were using.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Preview

Generated from the current Clipo UI components so the README stays aligned with the app.

![Clipo workflow](docs/assets/clipo-workflow.gif)

<p align="center">
  <img src="docs/assets/clipo-overview.png" alt="Clipo overview panel" width="49%" />
  <img src="docs/assets/clipo-search.png" alt="Clipo search and image preview" width="49%" />
</p>

## Highlights

- Menu bar app with no Dock icon
- Global hotkey for quick access
- Searchable clipboard history
- Inline image previews in the popup
- Pin important items
- Automatic history cleanup with pinned-item protection
- Auto-paste with Accessibility permission
- Better clipboard parsing for browser and Figma content

## Install

### Download a release

1. Open [Releases](https://github.com/bloodstalk1/Clipo/releases)
2. Download the latest `.dmg`
3. Open the DMG and drag `Clipo.app` into `Applications`

### Build from source

```bash
git clone https://github.com/bloodstalk1/Clipo.git
cd clipo
xcodegen generate
open Clipo.xcodeproj
```

Run the app from Xcode with `Cmd + R`.

### Package a DMG

```bash
xcodegen generate
./scripts/package_dmg.sh
```

This creates a drag-to-install DMG with `Clipo.app` and an `Applications` shortcut.

## Usage

1. Open Clipo from the menu bar icon or with `Cmd + Shift + V`
2. Search or browse your clipboard history
3. Click an item to restore and paste it
4. Pin important items so they stay around longer
5. Remove individual items or clear history when needed

## Permissions

Clipo needs Accessibility permission only for auto-paste.

1. Open Clipo
2. Use the permission prompt inside the popup
3. Enable Clipo in `System Settings > Privacy & Security > Accessibility`

If Accessibility is not enabled, Clipo still stores history and restores items to the clipboard. You can paste manually with `Cmd + V`.

## Requirements

- macOS 13 or later
- Apple Silicon or Intel Mac

## Tech Stack

- Swift 6
- SwiftUI + AppKit
- GRDB.swift
- KeyboardShortcuts
- XcodeGen

## Project Structure

```text
Clipo/
├── App/
├── Features/
├── Models/
├── Persistence/
├── Support/
└── Resources/
```

## License

MIT License. See `LICENSE` for details.
