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
- **Reconnect to Mosaic** — drops and rebuilds the connection
  immediately (put it on the connection-status button).

## Feedbacks

- **Profile is active** — button lights up while the chosen profile is
  active in Mosaic, no matter how it was switched (Stream Deck, hotkey,
  or Mosaic's own sidebar).
- **Connection to Mosaic lost** — button turns red while Companion
  cannot reach Mosaic. The link is watched with a 5-second heartbeat,
  so a frozen or quit Mosaic is detected within ~12 seconds even if
  the network socket looks open. Reconnection is attempted
  automatically; the Reconnect action forces it instantly.

## Variables

- `$(mosaic:current_profile)` — the active profile name
- `$(mosaic:display_mode)` — windowed / fullscreen / windowless
- `$(mosaic:tile_count)` — number of tiles on the canvas
- `$(mosaic:connection)` — `ok` or `lost`

## Presets

Ready-made buttons appear under **Presets** once connected: one for
every saved profile (with active-profile feedback), one per layout,
and a **Status** button that shows the connection state, turns red
when the link is lost, and reconnects when pressed.

---
NDI® is a registered trademark of Vizrt NDI AB.
