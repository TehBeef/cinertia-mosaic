# Mosaic User Guide

Mosaic is a professional multiviewer for NDI® video sources by Cinertia
Systems. It discovers NDI® sources on your network and displays them as
freely arrangeable tiles — with per-tile zoom, crop, rotation, instantly
switchable profiles, and Stream Deck remote control.

> This document is kept up to date with every feature and is the basis
> for the published user guide.

---

## Installing

Run `Mosaic-Setup-<version>.exe`. It installs to Program Files with a
Start Menu entry (desktop icon optional) and everything bundled — no
other software needed. The first time Mosaic runs, **Windows Firewall
asks for network access: click Allow** (NDI® needs it to find and
receive streams).

---

## The main window

- **Sidebar** (left): the Mosaic logo with the settings gear ⚙ and
  collapse « buttons, then three sections — NDI® Sources, Layouts,
  Profiles — and the required ndi.video link.
- **Canvas** (right): your tiles. Tiles use the entire canvas.
- **Status bar** (hidden): move the mouse to the bottom edge of the
  canvas to reveal the selected tile's name and stream info
  (resolution @ frame rate, low-latency marker).

The sidebar collapses with « and auto-collapses in fullscreen and
windowless modes. Hover the **left screen edge** and click » to bring it
back.

---

## Sources

- Sources on the network appear automatically (the list refreshes every
  second).
- **Click a source to add it** to the canvas as a tile. **Click it again
  to remove it.** The blue highlight shows which sources are on the
  canvas.
- You can also remove any tile with the ✕ in its header (hover the tile
  to see it).

### Duplicate sources (optional)
Turn on **Settings → Allow duplicate sources** and every sidebar click
adds **another copy** of that source instead of toggling it. The same
source can then be on the canvas many times — e.g. one wide camera shot
with several tiles each cropped to a different area. The blue badge
shows how many copies are up (● 3). With duplicates on, tiles are
removed only with their header ✕. Note that each copy is its own NDI
connection — use the tile's Low bandwidth option on small crop tiles to
keep network/CPU use down.

---

## Tiles

Hover a tile to reveal its **header**: the name, then
⟲ ⟳ (rotate 90°), Crop, Fit, Size, ⋯ (options), ✕ (close).

### Selecting
Click a tile to select it — it gets a blue border and comes to the
front. The border fades after a few seconds of mouse inactivity and
reappears when you move the mouse, so a nudge always shows the active
tile. Click empty canvas to deselect.

### Moving and resizing
- **Drag the tile** (anywhere on the picture at normal zoom, or always
  by the header) to move it.
- **Drag a corner** to resize (minimum 160×90).
- **Snap to grid:** hold **Ctrl** while dragging, or turn on **Snap**
  in the Layouts section. The grid appears on the canvas only while you
  drag with snapping active.
- **Size** button: type an exact width × height in pixels.

### Looking around inside a tile (all GPU, instant)
- **Zoom:** scroll wheel or trackpad pinch — zooms toward the cursor
  (10%–3200%).
- **Pan:** when zoomed in past 100%, drag the picture.
- **Rotate:** Alt+scroll for fine steps, or the ⟲ ⟳ header buttons for
  90° jumps.
- **Crop:** click **Crop**, drag a box over the region you want; the
  tile shows only that region. Crops can be stacked. Esc cancels.
- **Double-click:** reset zoom/pan.
- **Fit:** resets everything *and* reshapes the tile to the video's
  aspect ratio — picture fills the frame, no black bars.

### Tile options (the ⋯ menu)
Click ⋯ in the tile header (click anywhere else to close it):
- **Tile name:** type a custom label (e.g. `CAM 1 — STAGE LEFT`);
  empty = the NDI® source name.
- **Source name:** show/hide this tile's label overlay.
- **Audio meter:** two-bar peak meter (green/yellow/red) on the right
  edge. Visual only; audio is only processed while the meter is shown.
- **Low bandwidth:** receive the NDI® proxy stream — much lighter on
  network/CPU, ideal for small tiles. The tile reconnects briefly.
- **Low latency:** bypass the frame-sync buffer and show frames the
  moment they arrive — roughly a frame less delay, slightly less smooth
  motion. Great for a camera you cue talent from.

All options are saved with profiles and the session.

---

## Layouts

The **Layouts** section arranges the tiles currently on the canvas:
- **2×2, 3×3, 4×4** — grids (extra tiles continue in more rows)
- **1+side** — one large tile, the rest stacked beside it
- **2+8** — classic production multiview: two large monitors on top,
  rows of four below
- **Snap** — always-on snap-to-grid toggle

**Tile spacing** (settings): the gap the layouts leave between tiles,
0–64 px. **0 = seamless**, edge to edge.

---

## Profiles

A profile is a complete setup: which sources are up, tile positions and
sizes, every zoom/crop/rotation, names, and options.

- **Save:** arrange the canvas, type a name in the Profiles box, click
  **Save**.
- **Switch:** click a profile — or press **Ctrl+1…Ctrl+9** for the
  first nine, or trigger remotely (below). Switching is instant:
  sources shared between profiles never disconnect.
- **The active profile auto-saves.** Any change you make while a
  profile is active (highlighted) is folded into it automatically. The
  Save button is only for creating new profiles.
- **Delete:** hover a profile, click ✕.

Mosaic also autosaves the whole session every 5 seconds and restores it
on launch — even after a crash or power loss.

---

## Display modes (settings, or hotkeys)

- **Windowed** — normal window.
- **Fullscreen** — borderless fullscreen; pick the monitor in settings
  when more than one is connected. **F11** toggles it.
- **Windowless** — no title bar, pure canvas. Drag empty canvas to move
  the window; grab any edge or corner to resize.
- **Esc** always returns to windowed.
- **Always on top** keeps Mosaic above other windows.

---

## Settings reference (gear ⚙)

| Setting | What it does |
|---|---|
| Display mode | Windowed / Fullscreen / Windowless |
| Fullscreen monitor | Which screen fullscreen uses |
| Window size | Exact window dimensions |
| Always on top | Float above other windows |
| Rotate with Alt+scroll | Toggle wheel rotation |
| Show tile names | Master switch for all tile labels |
| Allow duplicate sources | Off (default): sidebar clicks toggle a source on/off. On: each click adds another copy of the source |
| Keep display awake | Stops Windows blanking the screen (show days) |
| Remote control + port | The Companion/Stream Deck TCP interface |
| Tile spacing | Gap used by layouts; 0 = seamless |
| About Mosaic… | Version, support contact, NDI® notices |

Settings, profiles, and the session are stored per user in
`%APPDATA%\Cinertia Systems\Mosaic\`.

---

## Hotkeys

| Key | Action |
|---|---|
| Ctrl+1 … Ctrl+9 | Switch to profile 1–9 (sidebar order) |
| F11 | Toggle fullscreen |
| Esc | Cancel crop / close dialogs / back to windowed |
| Ctrl (held while dragging) | Snap to grid |
| Alt+scroll | Rotate the video under the cursor |

---

## Remote control (Stream Deck / Bitfocus Companion)

Enable **TCP remote control** in settings (default port **9955**; the
green dot confirms it's listening).

### The native Companion module (recommended)

A dedicated **Cinertia Mosaic** Companion module ships with the project
(`companion-module\companion-module-cinertia-mosaic`). It gives you
profile dropdowns fed live from Mosaic, ready-made preset buttons for
every profile and layout, **active-profile button feedback** (the
button lights while its profile is live, however it was switched), and
variables like `$(mosaic:current_profile)`.

To install it (Companion 3.5 or newer): open Companion's web interface
→ **Modules** tab → **Import module package** → choose the
`cinertia-mosaic-x.y.z.tgz` bundle (built with
`npx companion-module-build` in
`companion-module\companion-module-cinertia-mosaic`, and included in
the distribution package). Then add a **Cinertia Mosaic** connection
and enter Mosaic's IP and port.

For development, the older route still works: point the Companion
launcher's **Developer modules path** at the `companion-module` folder.

### The generic fallback

Any controller that can send raw TCP text works. In Companion, add a
**Generic TCP/UDP** connection to this PC's IP on that port, then put
commands on buttons — one per line, case-insensitive:

| Command | Action |
|---|---|
| `PROFILE Show A` | switch to a profile by name |
| `PROFILEINDEX 2` | switch to the 2nd profile in the list |
| `LAYOUT 2x2` | apply a layout (2x2, 3x3, 4x4, 1+side, 2+8) |
| `MODE fullscreen` | windowed / fullscreen / windowless |
| `PING` | connectivity check |
| `PROFILES?` | replies `PROFILES ["Show A", …]` |
| `STATUS?` | replies `STATUS {"profile":…,"mode":…,"tiles":…}` |

Mosaic replies `OK`/`ERR …` per command and **pushes state changes** to
all connected clients (`EVENT PROFILE …`, `EVENT PROFILES …`,
`EVENT MODE …`) no matter what caused them — the foundation for
active-profile button feedback. If Companion runs on another machine,
allow Mosaic through Windows Firewall when prompted.

---

## Support

- Email: max@cinertia.systems
- Web: https://cinertia.systems

NDI® is a registered trademark of Vizrt NDI AB. Learn more at
[ndi.video](https://ndi.video/).
