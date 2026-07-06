# Project: NDI Multiviewer (working title)

## Who I am
I am an IT/AV professional, not a programmer. You (Claude) write all the code. Explain decisions in plain English, avoid jargon, and never assume I can debug code myself. When something needs testing, build the app and tell me exactly what to click and what I should see. I will test against real NDI sources on my network and give feedback in plain language.

## Ways of working
- Use git. Commit after every working milestone with a clear message. If I say "roll back," restore the last working commit.
- Work in the milestone order below. Do not skip ahead. Get my sign-off before moving to the next milestone.
- After each build, launch the app (or tell me how) so I can verify.
- If a library, tool, or SDK is missing, install or configure it yourself and tell me what you did.
- Keep a running NOTES.md explaining the project structure in plain English so I always understand what exists.

## What we are building
A professional NDI multiviewer for the AV/broadcast industry. It receives multiple NDI video streams from the network and displays them in a flexible canvas of tiles the user can freely arrange.

### Core features
1. **NDI source discovery** — automatically find all NDI sources on the network; user picks which to add. Allow manual IP/discovery-server entry as well.
2. **Multi-source canvas** — each source lives in its own tile. Tiles can be freely moved and resized (drag, corner handles). Optional snap-to-grid and preset layouts (2x2, 3x3, 1 large + sidebar, etc.).
3. **Per-source transforms (GPU-based)** — within each tile the user can:
   - Zoom in/out (scroll wheel), pan around the zoomed image (click-drag)
   - Crop (adjustable UV window)
   - Scale and rotate
   - One-click reset to fit
   These must be done on the GPU (texture coordinates / transform matrix on a textured quad), never by re-decoding.
4. **Display modes**
   - Windowed: normal resizable window
   - Fullscreen: borderless fullscreen, user selects which monitor
   - Windowless: frameless canvas (optionally per-tile frameless floating windows), always-on-top toggle, controls appear on hover only, Esc returns to windowed
5. **Per-tile options** — source name overlay toggle, audio meter overlay (visual only for v1), low-bandwidth/proxy stream toggle for small tiles, tally border support later.
6. **Persistence** — save/load named layouts (JSON), remember last session.

### Look and feel
- Dark theme only for v1. Near-black background (#0e0e10 range), subtle 1px borders, thin accent color on active/selected tile.
- Modern, clean, flat. Think professional broadcast multiviewer / Resolve / Companion — NOT a consumer media player.
- Minimal chrome. UI elements reveal on hover and get out of the way.
- Smooth 60fps UI interactions; video tiles render at source frame rate.

## Technical direction (agreed, do not relitigate unless there is a blocking problem)
- **Language/framework:** C++17 or newer with Qt 6 (QML/Qt Quick front end, C++ backend). Rendering through Qt RHI (Direct3D on Windows, Metal on macOS later).
- **NDI:** official NDI SDK (free version), receive-only for v1. One receive thread per source. Use the NDI frame sync API for smooth frame timing. Frames upload to GPU textures (handle UYVY and BGRA).
- **Build system:** CMake. Must remain cross-platform-clean so a macOS build is possible later without a rewrite. Isolate all platform-specific code.
- **Performance:** NDI decode is CPU-bound. Target: 9 simultaneous 1080p sources on a modern desktop CPU without dropped frames. Use proxy/low-bandwidth receive for tiles rendered small.
- **Windows packaging (later milestone):** Inno Setup installer producing a single .exe installer. NDI DLLs ship inside the application folder — never the system path.

## NDI SDK license compliance (required, build these in)
- Provide a visible link to ndi.video near where NDI sources are selected, and in the About dialog.
- About dialog must state: "NDI® is a registered trademark of Vizrt NDI AB."
- Use the ® mark on first use of "NDI" in any document/screen.
- Do not name the product with "NDI" in the product name without approval from the NDI team (use a codename for now).
- Bundle NDI runtime DLLs in the app folder per the SDK's software distribution terms.

## Milestones
1. **Environment setup** — install/verify compiler, CMake, Qt 6, locate the NDI SDK on this machine. Produce a hello-world Qt window with the dark theme shell. Confirm it builds and runs.
2. **Single-source viewer** — discover NDI sources, pick one, display it in a window at correct aspect ratio and frame rate.
3. **Transforms** — zoom, pan, rotate, crop, reset on that single source. GPU-based. Must feel instant.
4. **Multi-tile canvas** — multiple sources, movable/resizable tiles, snap-to-grid, preset layouts.
5. **Display modes** — fullscreen (monitor picker), windowless/frameless, always-on-top, hover-reveal controls.
   - Max (2026-07-06): in fullscreen and windowless modes the source sidebar must collapse or go away; put the settings menu/icon in the sidebar. Settings menu gets a toggle for scroll-wheel rotation (bound to Alt+scroll, on by default). Ctrl is reserved for snapping on the canvas — never bind Ctrl+scroll to rotation because trackpad pinch arrives as Ctrl+scroll on Windows.
6. **Polish** — layout save/load, per-tile options, proxy stream toggle, source name overlays, About dialog with NDI compliance items.
   - Max (2026-07-06): more layout preset options; save/load named layouts; reopen with the last view restored; premade broadcast multiview layouts (e.g. 1+3, 2+8, 4×4, classic production multiview arrangements).
   - Max (2026-07-06): while a tile is being dragged with snapping active, draw the snap grid on the canvas background — only during the drag, and only when snap mode is on.
7. **Installer** — Inno Setup .exe installer, version numbering, app icon.
8. **(Future) macOS port** — do not build now, but never introduce Windows-only dependencies without flagging it to me.

## Definition of done for v1
I can run the installer on a clean Windows machine, launch the app, add 4+ live NDI sources from my network, arrange them how I want, zoom into a detail on one of them, go fullscreen on a second monitor, and it looks and feels like a professional broadcast tool.
