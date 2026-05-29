# Tortoise

`Tortoise` is a lightweight macOS menu bar app inspired by the idea behind CPU runner utilities like RunCat, but built as a tiny Swift package that you can read, trust, and open-source.

This first pass stays deliberately small:

- original tortoise animation drawn in code
- menu bar icon that speeds up with live CPU usage
- optional CPU percentage beside the runner
- launch-at-login toggle
- no private APIs or special permissions

## Why this shape

The goal is to keep the app easy to reason about:

- a single Swift executable target
- AppKit status item with a small SwiftUI popover
- one model for CPU sampling, animation, and app settings
- a script that builds a standalone `.app` bundle

That makes it straightforward to audit, modify, and publish.

## Run locally

```bash
swift run Tortoise
```

## Build an app bundle

```bash
./scripts/make-app.sh
```

That creates `dist/Tortoise.app`.

## Project layout

- `Sources/Tortoise/TortoiseApp.swift`: app entry point and app icon
- `Sources/Tortoise/StatusItemController.swift`: menu bar status item and popover wiring
- `Sources/Tortoise/MenuBarContent.swift`: small control surface
- `Sources/Tortoise/TortoiseModel.swift`: CPU sampling, animation cadence, and launch-at-login
- `scripts/generate-icon.swift`: generated app icon artwork
- `scripts/make-app.sh`: release app bundle builder

## Next ideas

- additional runners or themes
- per-core or memory-based animation modes
- custom frame sets loaded from JSON or image strips
- Sparkle or GitHub Releases distribution
