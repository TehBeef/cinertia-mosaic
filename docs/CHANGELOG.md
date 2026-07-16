# Mosaic Changelog

All user-facing changes, newest first. Mosaic is a professional NDI®
multiviewer by Cinertia Systems. NDI® is a registered trademark of
Vizrt NDI AB.

---

## 0.6.0 — 2026-07-16

### Viewing
- **Fit respects rotation:** Fit now fits the picture at its current
  angle instead of undoing the rotation. On an uncropped tile it also
  reshapes the tile to the rotated picture's outline, always within the
  tile's current footprint — a 90°-turned source gets a narrower tile,
  never a larger one. Cropped tiles keep their size and shape.
- **Rotated tiles stay fitted:** resizing a tile re-fits a rotated
  picture continuously, and rotating keeps the picture inside the tile
  — the same behavior unrotated tiles have always had.
- **Reset button** in the tile header: one click undoes crop, rotation,
  zoom and pan, returning the tile to the plain source. Tile size is
  untouched.

### Interface
- **Compact tile header:** when a tile is too narrow to fit all header
  buttons, the header collapses to ☰ and ✕ — the ☰ menu offers every
  action (rotate, crop, fit, reset, size, options) and scrolls on short
  tiles instead of being cut off.
- **Tile panels fit narrow tiles:** the options and size panels shrink
  to the tile's width, and scrolling over any tile panel no longer
  zooms the video underneath.
- **Shortcuts dialog:** every keyboard and mouse shortcut, grouped by
  where it applies, under Settings → Shortcuts… — replacing the dense
  tips paragraph at the bottom of the settings panel.
- **About dialog:** added a link to the GitHub project (downloads and
  release notes); the NDI® notices are grouped at the bottom.

### Updates
- **Update notice (new setting, on by default):** Mosaic asks GitHub
  once at startup whether a newer release exists. If so, a small
  "Update available — Download" line appears at the bottom of the
  sidebar and in the About dialog, linking to the release page.
  Nothing downloads or installs automatically, and the check is
  silent when offline — updating stays a deliberate act on show
  machines. Turn it off with Settings → Check for updates at startup.

---

## 0.5.5 — 2026-07-11

### Monitoring
- **Stream status indicators (new setting, on by default):** a small
  red dot in a tile's top-left corner appears when the tile loses its
  live connection to the source — the sender is closed or gone from the
  network. A connected source shows no dot, including still images,
  slides and other static pictures (they send no new frames yet are
  perfectly alive).

### Interface
- **2+1 layout preset:** two tiles side by side on top, the remaining
  tiles sharing one large row below — e.g. two cameras over a
  full-width multiview. Also available to remote control (LAYOUT 2+1).
- **Hide mouse when idle (new setting, on by default):** the cursor
  disappears after 3 seconds without movement while over the tile
  canvas — never over the sidebar or menus — and returns the moment
  the mouse moves.
- **Linked borders (Alt+resize):** holding Alt while resizing makes
  touching tiles resize together — a shared border moves for every
  tile on it, and an outer edge of a touching group moves every group
  tile's matching edge to the same line. Without Alt, resizing affects
  only the grabbed tile.
- **Move tiles together:** Alt+drag moves a tile and every tile
  touching it as one group.

---

## 0.5.0 — 2026-07-10

### Performance
- **Video conversion moved to the GPU:** NDI® frames previously had
  their pixel format converted on the CPU before display — the single
  largest per-frame cost for large tiles. Frames now upload in their
  native format and convert on the graphics card, roughly halving
  per-frame CPU work and memory traffic for full-resolution sources.
- **Auto low bandwidth for small tiles (new setting, on by default):**
  tiles rendered at proxy size or smaller automatically switch to the
  NDI® proxy stream and back, cutting CPU and network use on dense
  multiview grids. The per-tile Low bandwidth toggle still forces the
  proxy stream at any size.
- **Sources are polled at their own frame rate:** each receive poll
  costs a frame copy inside the NDI® frame sync, so a 30 fps camera is
  now polled 30 times a second instead of 60.
- **Repeated frames are no longer reprocessed:** sources below 60 fps
  — and still images such as test patterns — previously had every
  frame copied and re-uploaded to the GPU 60 times a second. Unchanged
  frames are now skipped, substantially reducing CPU use per tile.

---

## 0.4.5 — 2026-07-10

### Tiles
- **Resize from any side:** tiles now resize by dragging any edge, not
  only the corners. Sides resize in one direction; corners resize
  freely. Snap-to-grid works on all of them.
- **Reposition the picture:** Shift+drag moves the video inside the
  tile frame at any zoom level. Double-click or Fit resets it.

---

## 0.4.0 — 2026-07-09

### Mosaic comes to the Mac
- **Native macOS version:** the full app — discovery, tiles, GPU
  transforms, layouts, profiles, multi-monitor canvases, display modes,
  hotkeys, remote control — now runs natively on Apple Silicon and
  Intel Macs (macOS 12+), rendering through Metal. Distributed as
  `Mosaic-<version>.dmg`; see the user guide's macOS install notes
  (first-launch right-click → Open, and the Local Network permission
  NDI® needs).
- **Keep display awake** works on macOS (IOKit power assertion — same
  behavior as on Windows).

### Fixed
- **Zoomed video stayed inside its tile border:** zooming a tile could
  paint the enlarged video over the tile's 1px border (visible on
  macOS). The video is now clipped to its own area on both platforms.

---

## 0.3.5 — 2026-07-09

### Tiles
- **Uncrop button:** removes a tile's crop and shows the full frame
  again. Appears in the tile header only while a crop is active.
- **Fit respects crops:** on a cropped tile, Fit now keeps the crop
  and the tile's current size and shape, refitting the cropped region
  inside the tile (zoom, pan and rotation reset). Previously Fit
  discarded the crop and reshaped the tile.

### Profiles
- **Keep canvases when switching profiles (new setting, on by
  default):** canvases not saved in the selected profile now stay open
  unchanged instead of closing. Turn the setting off to restore the
  previous behavior.

---

## 0.3.0 — 2026-07-08

### Multi-monitor canvases
- **Extra output canvases:** the sidebar's new **Canvases** section
  (+ Add) opens additional windows, each a full tile canvas of its
  own — build a different multiview look on every display.
- **Per-canvas window type:** every output canvas can be **Windowed**,
  **Fullscreen** (with a monitor picker), or **Windowless** (frameless
  — drag the background to move, grab any edge or corner to resize).
- **Per-canvas ⋯ menu at the bottom edge:** hover the bottom of an
  output canvas for its menu — placed at the bottom on purpose so it
  can never cover a tile's header or menu. It holds: rename the
  canvas, Send sources here, window type, exact size (width × height),
  monitor picker, and Close.
- **Canvas targeting:** the Canvases buttons choose which canvas
  sidebar source clicks and layout presets act on; the sources hint
  always shows where new tiles will land.
- **Full persistence:** profiles and the session save every canvas —
  tiles, name, window type, monitor and position — so a saved "look"
  restores across all displays, and switching profiles switches the
  whole multi-monitor setup at once.

### Tiles
- **Change source in place:** every tile's ⋯ menu ends with a
  **Change source** list of everything on the network. Pick one and
  the tile reconnects to it — position, size, options and custom label
  stay put; the view resets to fit the new picture.

### Fixes
- Resizing (or cropping) a tile in windowless mode no longer drags the
  whole window around.
- Output window chrome no longer flickers when the mouse crosses the
  reveal zone.

---

## 0.2.0 — 2026-07-07

First public-ready release: a single Inno Setup installer with
everything bundled (Qt runtime and NDI® DLL in the app folder).

### Production features
- **Profiles:** named setups bundling sources, layout and every
  tile's view. Click to switch instantly — shared sources never
  reconnect. The active profile auto-saves every change; the session
  also autosaves every 5 seconds and survives crashes and power loss.
- **Hotkeys:** Ctrl+1–9 switch profiles, F11 toggles fullscreen, Esc
  returns to windowed.
- **Stream Deck / Bitfocus Companion remote control:** TCP interface
  (default port 9955) with commands for profiles, layouts and display
  modes, plus live EVENT pushes for button feedback.
- **Native Companion module:** `cinertia-mosaic` importable module
  package — profile dropdowns fed live from Mosaic, presets for every
  profile and layout, active-profile button feedback and
  connection-status handling.
- **Keep display awake:** stops Windows from blanking the monitor
  during unattended operation.

### Tiles and sources
- **Per-tile options (⋯ menu):** custom tile name, source-name
  overlay, stereo audio peak meter, low-bandwidth (NDI® proxy) mode,
  low-latency mode.
- **Duplicate sources (opt-in):** one source on the canvas many times
  — e.g. several crops of a single wide shot.
- **Premade broadcast layouts:** 2×2, 3×3, 4×4, 1+side, 2+8.
- **Snap grid** drawn on the canvas only while dragging with snapping
  on; **tile spacing** setting (0 = seamless video wall).

### Polish
- About dialog with NDI® compliance items and support contacts.
- Auto-hide status bar with the selected tile's stream info.
- Selection border fades when idle and wakes on mouse movement.

---

## 0.1.0 — 2026-07-06

Internal milestone build — the first installer.

- **NDI® source discovery** with click-to-add sidebar.
- **Multi-tile canvas:** freely movable/resizable tiles, snap-to-grid,
  preset layouts.
- **GPU per-tile views:** zoom toward the cursor (10%–3200%), pan,
  rotate (Alt+scroll or 90° buttons), stackable crops, one-click Fit.
- **Display modes:** windowed, fullscreen with monitor picker,
  windowless (frameless) with always-on-top; auto-collapsing sidebar.
- **Windows installer** (Inno Setup) with app icon and version info.
