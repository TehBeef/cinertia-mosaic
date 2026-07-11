# Mosaic User Guide

Mosaic is a professional multiviewer for NDI® video sources by Cinertia
Systems. It discovers NDI® sources on your network and displays them as
freely arrangeable tiles — with per-tile zoom, crop, rotation, instantly
switchable profiles, and Stream Deck remote control.

> This document is kept up to date with every feature and is the basis
> for the published user guide. Version history lives in
> [CHANGELOG.md](CHANGELOG.md).

---

## Installing

### Windows

Run `Mosaic-Setup-<version>.exe`. It installs to Program Files with a
Start Menu entry (desktop icon optional) and everything bundled — no
other software needed. The first time Mosaic runs, **Windows Firewall
asks for network access: click Allow** (NDI® needs it to find and
receive streams).

### macOS

Open `Mosaic-<version>.dmg` and drag **Mosaic** into the **Applications**
folder shortcut next to it. Everything is bundled — no other software
needed. Apple Silicon and Intel Macs are both supported (macOS 12+).

First launch:

1. **Right-click Mosaic.app → Open → Open.** (A plain double-click is
   blocked the first time because this build isn't notarized with
   Apple; right-click → Open is the standard way around it and is only
   needed once.)
2. macOS asks **"Allow Mosaic to find devices on local networks?" —
   click Allow.** That permission is how NDI® finds and receives
   streams; without it the source list stays empty. If you missed the
   dialog, turn it on later in **System Settings → Privacy & Security →
   Local Network**.

Everything in this guide works the same on both platforms. Where a
keyboard shortcut says **Ctrl** or **Alt**, use **⌘ Cmd** / **⌥ Option**
on the Mac.

---

## The main window

- **Sidebar** (left): the Mosaic logo with the settings gear ⚙ and
  collapse « buttons, then four sections — NDI® Sources, Layouts,
  Canvases, Profiles — and the required ndi.video link.
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
⟲ ⟳ (rotate 90°), Crop, Uncrop (shown only while a crop is active),
Fit, Size, ⋯ (options), ✕ (close).

### Stream status indicator
A small dot appears in a tile's top-left corner when its stream has a
problem: **red** = not receiving (source offline, or the picture has
been frozen for more than 3 seconds), **yellow** = frames are stalling.
No dot means the stream is healthy. Turn the indicators on or off with
**Settings -> Stream status indicators**.

### Selecting
Click a tile to select it — it gets a blue border and comes to the
front. The border fades after a few seconds of mouse inactivity and
reappears when you move the mouse, so a nudge always shows the active
tile. Click empty canvas to deselect.

### Moving and resizing
- **Drag the tile** (anywhere on the picture at normal zoom, or always
  by the header) to move it.
- **Drag any side or corner** to resize (minimum 160×90). Sides resize
  in one direction; corners resize freely.
- **Snap to grid:** hold **Ctrl** while dragging, or turn on **Snap**
  in the Layouts section. The grid appears on the canvas only while you
  drag with snapping active.
- **Linked borders (Alt+resize):** hold **Alt** while resizing and
  touching tiles resize together. On a **shared border** (the divider
  between tiles), the border moves for every tile on it, both sides
  staying seamless. On an **outer edge** of a touching group, every
  group tile's matching edge moves to the same line — e.g. Alt+drag
  the bottom of one of two side-by-side tiles and both bottoms scale
  together. Without Alt, resizing only ever affects the tile you
  grabbed.
- **Move tiles together:** hold **Alt** and drag a tile to move it and
  every tile touching it as one group — lined-up tiles stay lined up.
- **Size** button: type an exact width × height in pixels.

### Looking around inside a tile (all GPU, instant)
- **Zoom:** scroll wheel or trackpad pinch — zooms toward the cursor
  (10%–3200%).
- **Pan:** when zoomed in past 100%, drag the picture.
- **Reposition:** **Shift+drag** moves the picture inside the tile
  frame at any zoom level — e.g. nudge a letterboxed image off-center.
  Double-click or **Fit** resets it.
- **Rotate:** Alt+scroll for fine steps, or the ⟲ ⟳ header buttons for
  90° jumps.
- **Crop:** click **Crop**, drag a box over the region you want; the
  tile shows only that region. Crops can be stacked. Esc cancels.
- **Uncrop:** removes the crop and shows the full frame again. The
  button appears in the header only while a crop is active.
- **Double-click:** reset zoom/pan.
- **Fit:** on an uncropped tile, resets the view *and* reshapes the
  tile to the video's aspect ratio — picture fills the frame, no black
  bars. On a **cropped** tile, Fit keeps the crop and the tile's
  current size and shape, and refits the cropped region inside the
  tile (zoom, pan and rotation reset).

### Tile options (the ⋯ menu)
Click ⋯ in the tile header (click anywhere else to close it):
- **Tile name:** type a custom label (e.g. `CAM 1 — STAGE LEFT`);
  empty = the NDI® source name.
- **Source name:** show/hide this tile's label overlay.
- **Audio meter:** two-bar peak meter (green/yellow/red) on the right
  edge. Visual only; audio is only processed while the meter is shown.
- **Low bandwidth:** receive the NDI® proxy stream — much lighter on
  network/CPU, ideal for small tiles. The tile reconnects briefly.
  (Small tiles switch to the proxy stream automatically when
  **Settings → Auto low bandwidth for small tiles** is on; this toggle
  forces it at any size.)
- **Low latency:** bypass the frame-sync buffer and show frames the
  moment they arrive — roughly a frame less delay, slightly less smooth
  motion. Great for a camera you cue talent from.
- **Change source:** pick any discovered source from the list to switch
  this tile to it **in place** — no deleting and re-adding. The tile
  keeps its position, size, options and custom label; the view resets
  to fit the new picture. The current source is highlighted.

All options are saved with profiles and the session.

---

## Layouts

The **Layouts** section arranges the tiles currently on the canvas:
- **2×2, 3×3, 4×4** — grids (extra tiles continue in more rows)
- **1+side** — one large tile, the rest stacked beside it
- **2+8** — classic production multiview: two large monitors on top,
  rows of four below
- **2+1** — two tiles side by side on top, the remaining tiles sharing
  one large row below (e.g. two cameras over one full-width multiview)
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

Profiles capture **every canvas** — the main one and any extra output
canvases (below), including which monitor each output is on and its
window type. Switching profiles switches the whole multi-monitor
look at once.

If you switch to a profile that doesn't include one of your open
canvases, the canvas **stays open unchanged** by default (and is added
to the now-active profile on its next auto-save). Prefer the canvas to
close instead? Turn off **Settings → Keep canvases when switching
profiles**.

---

## Multi-monitor canvases

Mosaic can drive more than one display: each **canvas** is its own
window full of tiles, and each can go fullscreen on a different
monitor — e.g. a producer multiview on your main screen and a clean
program/preview wall on the stage-left TV.

- **Add a canvas:** click **+ Add** in the sidebar's **Canvases**
  section. A new window opens ("Output 2", "Output 3", …) — on a second
  monitor by default when one is connected.
- **Canvas targeting:** the Canvases buttons choose which canvas sidebar
  source clicks and Layout presets act on. The blue source dots, the
  hint line ("→ Output 2") and the highlighted button always show where
  new tiles will land. You can also use **Send sources here** in an
  output window's ⋯ menu.
- **Output window controls:** hover the **bottom edge** and a small
  **⋯** button appears in the bottom-right corner — it lives at the
  bottom on purpose, so it can never cover a tile's header or menu
  (those are at the top of each tile). Click it for the menu: the
  canvas **name** (type to rename it — e.g. "STAGE LEFT WALL"; the
  window title and the sidebar's Canvases button follow), **Send
  sources here**, the **window type** (Windowed / Fullscreen /
  Windowless), an exact **size** (width × height, hidden while
  fullscreen — type the numbers and click **Set**), a **monitor
  picker** (1, 2, 3…), and **Close this canvas** (its tiles and
  connections are dropped). The menu opens upward and floats above the
  tiles, so nothing overlays your pictures until you open it.
- **Window types per canvas:** every output canvas has the same three
  modes as the main window — **Windowed** (normal window),
  **Fullscreen** (borderless, on the picked monitor), and
  **Windowless** (no title bar, pure canvas: drag empty canvas to move
  it, grab any edge or corner to resize). Inside the window, **F11**
  toggles fullscreen and **Esc** closes the menu / returns to a normal
  window.
- Tiles on an output canvas work exactly like on the main one: drag,
  resize, zoom, crop, swap sources, per-tile options, snap, layouts.
- Everything is remembered — profiles and the session store each
  canvas's tiles, monitor, window type and window position.
  Closing the main window closes the whole app (and saves first).

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
| Auto low bandwidth for small tiles | On (default): tiles rendered at proxy size or smaller automatically receive the lighter NDI® proxy stream, reducing CPU and network load. The tile reconnects briefly when it crosses the size threshold |
| Stream status indicators | On (default): a red/yellow dot on a tile whose stream is down or stalling |
| Hide mouse when idle | On (default): the mouse cursor disappears over Mosaic after 3 seconds without movement and returns when moved |
| Keep canvases when switching profiles | On (default): canvases not saved in the selected profile stay open unchanged. Off: they close |
| Keep display awake | Stops Windows blanking the screen (unattended operation) |
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
| Shift (held while dragging the picture) | Move the picture inside the tile |
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
| `LAYOUT 2x2` | apply a layout (2x2, 3x3, 4x4, 1+side, 2+8, 2+1) |
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
