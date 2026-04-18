# simple-editor

This repository is a minimal macOS note editor with a native feel.

## Goals
- TextEdit-like, lightweight memo app
- Auto-save, auto-generated filenames, left sidebar list
- No rich features (tags, markdown, etc.)
- Prefer macOS-native behavior and shortcuts

## Core Features
- Auto-save (after input settles)
- File creation: `~/.simple-editor` with `YYYYMMDD-HHMMSS.txt`
- Sidebar list (modified time + filename)
- Monospaced editor with line numbers
- Search (Cmd+F): in-file highlights + file list highlights
- Context menu: Save / Delete
  - Delete is a soft delete (rename with `_` prefix)
- Font size controls (Settings + Cmd +/-/0)
- Wrap / No Wrap (horizontal scroll supported)
- IME-safe auto-save (no saving during composition)

## Key Rules
- File storage: `~/.simple-editor`
- Files starting with `.` or `_` are hidden from the list
- Settings file: `~/.simple-editor/_config.json`
  - `fontSize`, `wrapLines`

## Tech Stack
- SwiftUI + AppKit (NSTextView for editor + line numbers)
- Swift Package Manager (SwiftPM)

## Important Files
- `Sources/SimpleEditor/App.swift`
  - App UI, menus, settings, window title
- `Sources/SimpleEditor/FileStore.swift`
  - File management, auto-save, config
- `Sources/SimpleEditor/EditorView.swift`
  - NSTextView wrapper, IME handling, key overrides
- `Sources/SimpleEditor/LineNumberRuler.swift`
  - Line number rendering
- `assets/AppIcon.png` / `assets/AppIcon.icns`
  - App icon assets

## Icon Workflow
- PNG → `.icns` via `icnsutil`
- `assets/SimpleEditor.iconset/` can be used for previews

## Build & Run
- Run: `swift run`
- Build: `swift build -c release`
- Create .app: `./build_app.sh`
  - Output: `dist/SimpleEditor.app`

## Distribution Notes
- Unsigned apps will show Gatekeeper warnings
- Proper distribution requires signing + notarization

## Dev Notes
- Respect `NSTextView.hasMarkedText()` to avoid IME issues
- Trigger save only after composition ends
- Ensure line-number redraw on content switches
- JIS keyboard: Cmd+ may come from `;` + Shift

## Typical Workflow
1. `swift run` for quick checks
2. Adjust UI / settings / icon
3. `./build_app.sh` to build `.app`
4. Copy to `/Applications` and test

## Development Notes
- When making changes, run `make build` and confirm the build passes.
- Follow `make format` formatting rules and run it when needed.
- When a feature is completed, record it in this AGENTS.md.

## Completed Features
- 2026-01-25: Prefer a CJK-capable monospaced font (e.g. Osaka-Mono) for equal-width glyphs.
- 2026-01-25: Persist left sidebar toggle state in config and restore on launch.
- 2026-03-03: On JIS keyboards, map `Shift+¥` to `|` while keeping `¥` key as `\` without Shift.
- 2026-03-03: Swap sidebar row order to show bold filename first and modified timestamp below.
- 2026-03-03: Replace sidebar "+ New" text with SF Symbol button (`square.and.pencil` + "New").
- 2026-03-03: Update sidebar new-file button text to "New file" and show gray hover background only on mouse over.
- 2026-03-03: Expand new-file button hover highlight to span the full available row width.
- 2026-04-18: Show sidebar modified dates as relative labels like `10 minutes ago`, `yesterday`, and `1 month ago`.
- 2026-04-18: Default sidebar file list to files modified within 2 months, with Show more / Show less for older files.
