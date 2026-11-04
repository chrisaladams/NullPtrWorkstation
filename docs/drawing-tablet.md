# Drawing tablets with LibreSprite

No tablet model is assumed. The image ships the generic Linux tablet stack:

| Layer | Package | Covers |
|---|---|---|
| Kernel | Debian kernel (`wacom`, `hid-uclogic`, `hid-generic`) | Wacom; most Huion/XP-Pen/Gaomon/Ugee through `hid-uclogic` or plain HID |
| X11 driver | `xserver-xorg-input-wacom` | Wacom devices: pressure, tilt, buttons configurable with `xsetwacom` |
| X11 driver | `xserver-xorg-input-libinput` | all other tablets: position, pressure, buttons as mouse buttons |
| Database | `libwacom-bin` | `libwacom-list-local-devices` identifies known models |
| Tools | `xinput`, `libinput-tools` | mapping and diagnostics |

## Commands

### `tablet-info`

Lists tablet-vendor USB IDs, kernel devices tagged `ID_INPUT_TABLET`, the X11 stylus/pad
devices and **which driver handles each one** (`xf86-input-wacom` or `libinput`), monitors,
and libwacom's identification.

### `tablet-setup`

```bash
tablet-setup                    # map every stylus/pen device to the primary monitor, save
tablet-setup --output HDMI-1    # map to another monitor (names from `xrandr` or tablet-info)
```

Settings go to `~/.config/nullptr/tablet.conf` and are re-applied at every graphical login
(`tablet-setup --apply` runs from the i3 config). Mapping uses `xinput map-to-output`, which
works for both drivers. On Wacom devices, pen buttons can be set in the same file:

```sh
OUTPUT=eDP-1
WACOM_BUTTON2="key ctrl z"      # lower pen button: undo
WACOM_BUTTON3="3"               # upper pen button: right click
```

## Drawing in LibreSprite

`art` (or `Super+A`) opens LibreSprite 1.2 on workspace 2, started in the active project's
`assets/` folder. Save sprites into `assets/` and they show up in the project immediately:
raylib loads `assets/x.png`, and Game Boy projects convert them with
`/opt/gbdk/bin/png2asset` (see [gameboy-debugging.md](gameboy-debugging.md)).

## Limitations (please read)

- **Pressure in LibreSprite:** LibreSprite 1.2 runs on SDL2, and SDL2 does not deliver stylus
  pressure to applications on X11. The pen draws as a mouse: position, click and buttons
  work, but stroke width/opacity won't follow pressure even if the driver reports it (check
  with `xinput test-xi2 --root`). This is an application limitation, not a configuration one.
- Some very new or very cheap tablets need kernel support that only arrives in later
  kernels, or the out-of-tree `digimend` driver (not in Debian). `tablet-info` shows whether
  the kernel recognised the device at all.
- Tablets with built-in screens (pen displays) usually need `tablet-setup --output <their
  output>`, otherwise the pen maps across all monitors.

## Test status

**NOT TESTED with a physical tablet.** None was available. Verified without one:
`tablet-info` runs and reports correctly, and `tablet-setup` explains clearly that no
stylus was found. Pressure, pen buttons and mapping need real hardware.
