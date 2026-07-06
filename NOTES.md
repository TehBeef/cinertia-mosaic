# Project Notes (plain English)

This file explains what exists in the project so far. It gets updated as we go.

## What this project is
A professional multiviewer for the AV/broadcast industry that receives NDI®
video streams over the network and shows them as arrangeable tiles.
NDI® is a registered trademark of Vizrt NDI AB.

**Codename: "Mosaic"** — we can't put "NDI" in the product name without
approval from the NDI team, so everything internal uses this codename for now.
Easy to rename later.

## Current status
**Milestone 5 complete and signed off.** Display modes (Windowed /
Fullscreen with monitor picker / Windowless with edge-resize), always on
top, collapsible sidebar (auto-collapses in fullscreen/windowless, left
edge hover brings it back), settings panel via the gear icon, Esc returns
to windowed. Layout presets live in the bottom status bar. Tile layouts
scale with the canvas so mode switches keep the arrangement.
Next: **Milestone 6 — polish/persistence**: profiles (named layout +
source + view bundles), save/load, restore last session, premade broadcast
multiview layouts, snap-grid shown while dragging, per-tile options,
About dialog. Later: hotkeys and Stream Deck/Companion remote control.
(Rotation is Alt+scroll — Ctrl is reserved for snapping; pinch = zoom.)

## A bug worth remembering (fixed 2026-07-06)
Sources seemed to vanish when switching display modes. Root cause: QML
TapHandler's default "passive grab" lets one click fire on several
overlapping controls at once — clicking mode buttons in the settings
panel ALSO clicked the source list underneath, toggling sources off.
Every tap button now uses gesturePolicy ReleaseWithinBounds (exclusive
grab). If a future click ever seems to "leak through" an overlay, check
for a TapHandler missing that policy.

## Files in the project

| File / folder | What it is |
|---|---|
| `CLAUDE.md` | The project brief — goals, milestones, rules. Claude reads this every session. |
| `NOTES.md` | This file. Plain-English map of the project. |
| `CMakeLists.txt` | The build recipe. Tells CMake how to compile the app and which Qt pieces it needs. |
| `src/main.cpp` | The C++ entry point. Starts the NDI library and loads the user interface. |
| `src/ndi/NdiFinder.h/.cpp` | Watches the network for NDI sources (checks once a second) and feeds the sidebar list. |
| `src/ndi/NdiVideoItem.h/.cpp` | The video tile. Each one runs its own background thread that receives one NDI stream (using NDI's frame-sync for smooth timing) and draws the frames on screen, letterboxed to the correct aspect ratio. Also owns the view math: zoom/pan/rotate are a transform matrix on the video rectangle, crop is a "window" into the video texture — all GPU work. |
| `qml/Main.qml` | The main window: source sidebar (click to add/remove tiles, required ndi.video link), the tile canvas, layout presets + snap toggle, and the status strip. |
| `qml/Tile.qml` | One tile on the canvas: hover header (drag to move, rotate/crop/fit/close buttons), corner resize grips, snap-to-grid logic, crop overlay. The live video inside is a `VideoView` from NdiVideoItem. |
| `.gitignore` | Tells git to ignore build output and editor junk. |
| `build/` | (created during builds) Compiled output. Never edited by hand, safe to delete. |

## Tools installed on this machine for the project
- **Git** — version history / rollback safety net (was already installed)
- **Visual Studio 2022 Build Tools** — the C++ compiler (installed via winget)
- **CMake** — the build system that drives the compiler (installed via winget)
- **Qt 6.8.3** — the UI framework, installed to `C:\Users\Max\Qt` (via aqtinstall)
- **NDI 6 SDK** — the developer kit for receiving NDI streams (downloaded from ndi.video)
- **NDI 6 Runtime + Tools** — were already installed (Studio Monitor, Test Patterns, etc.)

## How the app gets built (for reference)
1. CMake reads `CMakeLists.txt` and generates build files in `build/`
2. The Visual Studio compiler turns the C++ and QML into `build/Mosaic.exe`
3. Qt's DLLs must be next to the exe (or on PATH) for it to run — the build
   steps handle this.
