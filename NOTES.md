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
**Milestone 3 — GPU view transforms.** Zoom (scroll), pan (drag), rotate
(Ctrl+scroll or 90° buttons), crop (drag a box), and reset — all done on
the GPU by moving a transform matrix / texture window, never by
re-decoding video. Awaiting Max's feel test.
(Milestones 1–2 are complete and signed off.)

## Files in the project

| File / folder | What it is |
|---|---|
| `CLAUDE.md` | The project brief — goals, milestones, rules. Claude reads this every session. |
| `NOTES.md` | This file. Plain-English map of the project. |
| `CMakeLists.txt` | The build recipe. Tells CMake how to compile the app and which Qt pieces it needs. |
| `src/main.cpp` | The C++ entry point. Starts the NDI library and loads the user interface. |
| `src/ndi/NdiFinder.h/.cpp` | Watches the network for NDI sources (checks once a second) and feeds the sidebar list. |
| `src/ndi/NdiVideoItem.h/.cpp` | The video tile. Each one runs its own background thread that receives one NDI stream (using NDI's frame-sync for smooth timing) and draws the frames on screen, letterboxed to the correct aspect ratio. Also owns the view math: zoom/pan/rotate are a transform matrix on the video rectangle, crop is a "window" into the video texture — all GPU work. |
| `qml/Main.qml` | The user interface: source sidebar (with the required ndi.video link), video viewer, hover toolbar (rotate/crop/reset), crop-selection overlay, and status strip showing resolution/frame rate. |
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
