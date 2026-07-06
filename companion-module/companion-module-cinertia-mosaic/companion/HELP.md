# Cinertia Mosaic

Controls the **Cinertia Mosaic** NDI® multiviewer over the network.

## Mosaic setup

1. In Mosaic, open **Settings** (gear icon in the sidebar).
2. Turn on **Enable TCP remote control** (default port 9955) and check
   for the green "listening" indicator.
3. If Companion runs on a different machine, allow Mosaic through
   Windows Firewall when prompted.

## Connection

- **Mosaic IP address** — the IP of the PC running Mosaic
  (`127.0.0.1` if Companion runs on the same machine).
- **Port** — must match the port in Mosaic's settings (default 9955).

## Actions

- **Switch profile** — pick a profile from the live list.
- **Switch profile by position** — 1 = first profile in Mosaic's sidebar.
- **Apply layout** — 2×2, 3×3, 4×4, 1 large + side column, 2 large + rows of 4.
- **Set display mode** — windowed, fullscreen, windowless.
- **Ping** — connectivity check.

## Feedbacks

- **Profile is active** — button lights up while the chosen profile is
  active in Mosaic, no matter how it was switched (Stream Deck, hotkey,
  or Mosaic's own sidebar).

## Variables

- `$(mosaic:current_profile)` — the active profile name
- `$(mosaic:display_mode)` — windowed / fullscreen / windowless
- `$(mosaic:tile_count)` — number of tiles on the canvas

## Presets

Ready-made buttons for every saved profile (with active-profile
feedback) and every layout appear under **Presets** once connected.

---
NDI® is a registered trademark of Vizrt NDI AB.
