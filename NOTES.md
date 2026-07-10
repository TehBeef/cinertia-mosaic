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
**Current release: 0.3.5** — `dist\Mosaic-Setup-0.3.5.exe`, with the
full distribution package in `dist\Mosaic-0.3.5-Package(.zip)`:
installer + PDF user guide + README + Companion module. Version
history: `docs/CHANGELOG.md`.

**New in 0.3.5 (tested and signed off by Max):**
1. **Uncrop button + Fit respects crops** — Uncrop appears in a tile's
   header while a crop is active and removes it. Fit on a cropped tile
   keeps the crop and the tile's size/shape, refitting the cropped
   region inside the tile; Fit on an uncropped tile behaves as before
   (reset view + reshape tile to the video's aspect).
2. **Keep canvases when switching profiles** — new setting (on by
   default): canvases a profile doesn't include stay open unchanged
   instead of closing.

**0.3.0 features (tested and signed off by Max):**
1. **Swap a tile's source in place** — every tile's ⋯ menu now ends
   with a CHANGE SOURCE list of everything on the network. Click one
   and the tile reconnects to it; position, size, options and custom
   label stay put, the view resets to fit.
2. **Multi-monitor canvases** — the sidebar's new CANVASES section
   (+ Add) opens extra output windows, each a full canvas of its own.
   Hover the BOTTOM edge for a ⋯ dropdown (bottom on purpose — tile
   headers/menus are at the top, so the button can never block them):
   rename the canvas (live-edit name box, same style as tile rename),
   window type (Windowed / Fullscreen / Windowless), exact canvas size
   (width × height + Set, like the main settings panel), monitor
   picker, send-sources-here, close. Windowless outputs are frameless — drag
   the canvas background to move, grab edges/corners to resize, Esc
   returns to a normal window. The Canvases buttons pick which canvas
   sidebar clicks and layout presets aim at. Profiles and the session
   save every canvas (old saves that stored just a fullscreen yes/no
   still load), so a saved "look" restores across all displays.
   Technical shape: the canvas was extracted from Main.qml into a
   reusable TileCanvas.qml; OutputWindow.qml wraps one in a
   frameless-friendly window; Main.qml keeps a model of outputs
   and routes sidebar actions to the targeted canvas.

**Milestone 6a — profiles & persistence (awaiting Max's test).**
Profiles live in the sidebar: type a name, hit Save, click a profile to
switch instantly (sources shared between profiles never reconnect).
The session autosaves every 5 seconds and restores on launch — verified
to survive even a hard process kill. New premade layouts 4×4 and 2+8
(classic production multiview). The snap grid appears on the canvas only
while dragging/resizing with snapping on. Saved files live in
`C:\Users\Max\AppData\Roaming\Cinertia Systems\Mosaic\`.
**Milestone 6b (awaiting Max's test):** every tile now has a ⋯ menu with
three toggles — Source name (broadcast-style label, on by default),
Audio meter (two-bar peak meter, right edge), and Low bandwidth (NDI
proxy stream for small tiles). All three stick with profiles and the
session. The active profile also auto-saves every change now — the Save
button is only for creating new profiles. About dialog (gear → About
Mosaic…) carries the NDI trademark notice and ndi.video link.
**Previous release: 0.2.0** — `dist\Mosaic-Setup-0.2.0.exe` contains
all v1 milestones plus profiles with autosave,
duplicate sources (opt-in), tile renaming, per-tile options (name /
meter / low bandwidth / low latency), hotkeys, never-sleep, and the
Companion TCP remote control with feedback protocol.
The installer is a single setup exe built with Inno Setup.
Installs to Program Files with the Qt runtime and the NDI DLL bundled in
the app folder (per the NDI license), Start Menu entry, optional desktop
icon, proper app icon and version info, no debug console window.
Rebuild it any time with `scripts\stage-deploy.ps1`.
**Show-day features (awaiting Max's test):** tile renaming (⋯ menu),
never-sleep ("Keep display awake" in settings), hotkeys (Ctrl+1–9 switch
profiles in list order, F11 toggles fullscreen, Esc returns to windowed),
and TCP remote control for Bitfocus Companion / Stream Deck.

## macOS port (milestone 8 — in progress, `macos-port` branch)
Porting the finished Windows app to the Mac. Work happens on the
`macos-port` branch so the Windows build on `master` keeps working.

**Done so far — the toolchain + a dark-theme hello-world window:**
- Installed the Mac build tools (see "Tools installed on the Mac" below).
- Built a tiny standalone hello-world app that is NOT the full Mosaic — it
  needs no NDI SDK, so its only job is to prove the Mac can build and run a
  Qt window with our dark theme before we wire NDI in. It lives in
  `dev/macos-hello/` and is completely separate from the real app's build,
  so it can never break Windows.
- It builds and runs: a near-black window titled "Mosaic — macOS port" with
  the Mosaic wordmark and accent colour, confirming **Qt 6.8.3** and, crucially,
  **render backend: Metal** (Apple M4). Metal is the Mac's GPU path — the same
  role Direct3D plays on Windows — so the GPU rendering the whole app relies on
  is confirmed working.

**Then the whole app built and ran — first live NDI video on the Mac.** The
full Mosaic app compiles and links on macOS unchanged (all the C++ including the
NDI receive code, and every Windows-only piece is already isolated so it just
compiles to a harmless no-op on Mac). It discovers NDI sources on the network
and plays one in a tile at the correct aspect ratio — verified against an NDI
Test Patterns source (colour bars), the full pipeline end to end: NDI receive →
frame decode → GPU texture → Metal render. Signed off by Max 2026-07-09.

**A macOS build gotcha found and handled:** on Windows the program is
`Mosaic.exe`; on the Mac a program has no `.exe`, so a bare `Mosaic` file
would collide with the `Mosaic` folder Qt generates for its QML. The fix is
the normal Mac way of shipping a program — an **app bundle** (`Mosaic.app`,
via `MACOSX_BUNDLE`). The NDI library (`libndi.dylib`) is bundled inside the
app at `Contents/Frameworks/` with an rpath, so the `.app` is self-contained —
the same "runtime ships inside the app" rule the Windows DLL follows.

**macOS permission prompts (important — these don't exist on Windows).** On a
first run macOS pops system dialogs the user must click **Allow** on, or NDI
won't work:
- **"…find devices on local networks?"** — gates NDI discovery *and*
  broadcasting. Every NDI app hits this (Mosaic, and e.g. NDI Test Patterns).
  Deny it and the source list stays empty forever. The grant reliably applies
  when the app is launched normally (Finder / LaunchServices), so launch the
  `.app`, not the bare binary, when testing discovery.
- **"…access files on a removable volume?"** — appears because the app runs
  from the external drive. One-time grant, then it sticks.
These are one-time per app. If discovery ever looks broken on a Mac, check
System Settings → Privacy & Security → Local Network first.

**Where things run from:** the internal Mac drive was essentially full, so the
project, the Qt install, and all build output live on the external **"Max
DeRoin"** drive. That drive must be mounted to build or run during development.

**Done:** toolchain, dark-theme hello-world, NDI SDK wired in, a single live
NDI source in a tile, and the rest of the app exercised on macOS — transforms
(zoom/pan/rotate/crop), multi-tile canvas + layout presets, and the
fullscreen/windowless/windowed modes (the risky part) all work, driven and
verified via the TCP remote control. Milestones 1–3 equivalent. Signed off by
Max 2026-07-09.

**One macOS render fix (2026-07-09):** a zoomed-in tile let the enlarged video
paint over the tile's 1px border — the video item wasn't clipping to its own
inset rect, so the zoomed content only stopped at the outer edge. Metal's
subpixel rounding made the bleed visible (Direct3D hid it). Fix: `clip: true`
on the `VideoView` in `Tile.qml`. Correct on both platforms.

**Heads-up — the external drive is exFAT and hits a macOS Sequoia bug.** Under
heavy I/O (e.g. a burst of rebuilds) the FSKit exFAT driver can start failing
ALL writes with "Operation not permitted" (EPERM) while reads still work and
`diskutil` still reports the volume read-write. It is not a permissions or git
problem. Fix: remount the volume —
`diskutil unmount force "/Volumes/Max DeRoin" && diskutil mount disk4s1`
(quit anything running from the drive first). A permanent fix would be
reformatting the drive to APFS/HFS+, but that erases it, so not now.

**All milestone-8 work is done — the Mac version ships as 0.4.0.**
- Never-sleep works on macOS (IOKit power assertion in `PowerGuard`,
  verified with `pmset -g assertions`; released on quit).
- App icon: `resources/mosaic.icns`, drawn at 1024px with real transparency
  (the first attempt via qlmanage had a white background — the icon is now
  generated with Pillow). Wired via `MACOSX_BUNDLE_ICON_FILE`.
- Bundle identity: `com.cinertiasystems.mosaic`, proper version strings, and
  a custom `resources/Info.plist.in` that adds the Local Network usage
  description (shown in the permission dialog) and the `_ndi._tcp` Bonjour
  service type.
- **Packaging:** `scripts/stage-deploy-mac.sh` (the Mac `stage-deploy.ps1`)
  builds → `macdeployqt` (bundles Qt + QML into the .app) → codesigns →
  produces `dist/Mosaic-<version>.dmg` with an /Applications shortcut.
  Verified self-contained: the app runs straight from the mounted dmg.
- **Signing:** ad-hoc (`codesign -s -`) for now — Max has no Apple Developer
  account yet. Consequences: on another Mac the first launch needs
  right-click → Open (documented in the user guide), and Gatekeeper shows a
  warning. When Max gets an Apple Developer account ($99/yr), set
  `SIGN_ID="Developer ID Application: …"` in the deploy script and add
  notarization (`xcrun notarytool`) — then it opens clean everywhere.

## Tools installed on the Mac (for the macOS port)
Everything sizable lives on the external **"Max DeRoin"** drive to keep the
near-full internal drive clear (Max's instruction). Only Apple's own tools and
Homebrew are on the internal drive (they were already there).
- **Xcode Command Line Tools** — Apple's C++ compiler (clang), was already installed (internal).
- **Homebrew** — Mac package manager, was already installed (internal).
- **CMake 4.3.3** — the build system, installed as a standalone copy on the
  external drive at `…/NDI Multiviewer - Mac/tools/` (symlinks in
  `tools/bin/`). Builds invoke it by that path. (Homebrew's CMake was removed
  to keep the internal drive clear.)
- **Qt 6.8.3** — the UI framework, matching the Windows 6.8.3 install; installed
  via aqtinstall to `…/NDI Multiviewer - Mac/Qt` on the external drive.
- **NDI SDK for Apple** — not yet installed (needs Max's license click; will go
  on the external drive).

## Where Mosaic lives online (2026-07-09)
- **Repo front page:** `README.md` (on master and macos-port) — logo, feature
  list, screenshots from `docs/guide-src/img/`, download + install for both
  platforms.
- **Website:** https://tehbeef.github.io/cinertia-mosaic/ — GitHub Pages,
  served from the `gh-pages` branch (a single `index.html` + `img/`; edit
  that branch to change the site). Set as the repo homepage.
- **Downloads:** GitHub Releases. `v0.4.0` carries `Mosaic-0.4.0.dmg` (the
  Mac disk image, built by `scripts/stage-deploy-mac.sh`). The Windows
  installer gets attached from the Windows machine after the next master
  build there.
- **Note for the Windows session:** `macos-port` is ready to merge into
  `master` — everything platform-specific is guarded (APPLE blocks in CMake,
  Q_OS_MACOS ifdefs), but per the ways of working, verify the Windows build
  compiles after merging before pushing, then rebuild the installer at 0.4.0
  and attach it to the v0.4.0 release.

## Remote control protocol (Companion "Generic TCP" module)
Enable in settings, default port 9955. One command per line:
| Command | What it does |
|---|---|
| `PROFILE Show A` | switch to a profile by name |
| `PROFILEINDEX 2` | switch to the 2nd profile in the list |
| `LAYOUT 2x2` | apply a layout (2x2, 3x3, 4x4, 1+side, 2+8) |
| `MODE fullscreen` | display mode (windowed, fullscreen, windowless) |
| `PING` | connectivity check |
| `PROFILES?` | replies `PROFILES ["Show A","Show B"]` (JSON list) |
| `STATUS?` | replies `STATUS {"profile":"Show A","mode":"windowed","tiles":3}` |
Mosaic replies `OK` or `ERR ...` per action command. Commands are
case-insensitive.

Mosaic also **pushes state changes** to every connected client, no matter
what caused them (sidebar click, hotkey, another controller):
- `EVENT PROFILE Show A` — active profile changed
- `EVENT PROFILES ["..."]` — the profile list changed
- `EVENT MODE fullscreen` — display mode changed
This is the foundation for a future native Companion module with active-
profile button feedback (see CLAUDE.md roadmap).

## New files for the installer
| File / folder | What it is |
|---|---|
| `resources/mosaic.ico` + `mosaic.rc` | The app icon and Windows version info baked into Mosaic.exe. |
| `installer/mosaic.iss` | The Inno Setup recipe for the installer. |
| `scripts/stage-deploy.ps1` | One command that rebuilds, stages a clean app folder (`deploy/`), and produces the installer in `dist/`. |
(Milestones 1–5 signed off. Rotation is Alt+scroll — Ctrl is snapping;
pinch = zoom.)

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
| `docs/USER-GUIDE.md` | The user-facing manual — every feature documented, kept current with each change, basis for the published guide. |
| `docs/CHANGELOG.md` | Version history — every user-facing change per release, newest first. Update it with each release. |
| `docs/guide-src/` | The styled HTML that becomes the PDF user guide in the distribution package (plus its screenshots). |
| `CMakeLists.txt` | The build recipe. Tells CMake how to compile the app and which Qt pieces it needs. |
| `src/main.cpp` | The C++ entry point. Starts the NDI library and loads the user interface. |
| `src/ndi/NdiFinder.h/.cpp` | Watches the network for NDI sources (checks once a second) and feeds the sidebar list. |
| `src/ndi/NdiVideoItem.h/.cpp` | The video tile. Each one runs its own background thread that receives one NDI stream (using NDI's frame-sync for smooth timing) and draws the frames on screen, letterboxed to the correct aspect ratio. Also owns the view math: zoom/pan/rotate are a transform matrix on the video rectangle, crop is a "window" into the video texture — all GPU work. |
| `qml/Main.qml` | The main window: source sidebar (click to add/remove tiles, required ndi.video link), layout presets + snap toggle, the CANVASES section (multi-monitor), profiles, settings, and all persistence. |
| `qml/TileCanvas.qml` | One tile canvas — tiles, selection, snap grid, preset layouts, profile capture/apply. The main window has one; every extra output window has its own. |
| `qml/OutputWindow.qml` | An extra output window (multi-monitor mode): wraps a TileCanvas, hover chrome at the top edge (monitor picker, fullscreen, close), Esc/F11 handling. |
| `qml/Tile.qml` | One tile on the canvas: hover header (drag to move, rotate/crop/fit/close buttons), ⋯ menu (rename, options, change source), corner resize grips, snap-to-grid logic, crop overlay. The live video inside is a `VideoView` from NdiVideoItem. |
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
