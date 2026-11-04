# Drawing tablets with LibreSprite

No tablet model is assumed. The image ships the generic Linux tablet stack:

| Layer | Package | Covers |
|---|---|---|
| Kernel | Debian kernel (`wacom`, `hid-uclogic`, `hid-generic`) | Wacom; most Huion/XP-Pen/Gaomon/Ugee through `hid-uclogic` or plain HID |
| X11 driver | `xserver-xorg-input-wacom` | Wacom devices: pressure, tilt, buttons configurable with `xsetwacom` |
| X11 driver | `xserver-xorg-input-libinput` | all other tablets: position, pressure, buttons as mouse buttons |
| Database | `libwacom-bin` | `libwacom-list-local-devices` identifies known models |
| Tools | `xinput`, `libinput-tools` | mapping and diagnostics |

## Your tablet: Huion Inspiroy H640P

| | |
|---|---|
| USB ID | `256c:006d` (shared by many Huion models; the kernel tells them apart by firmware string) |
| Kernel | `hid-uclogic`. Linux 6.12 (Debian 13) handles `256c:006d` and probes the firmware for the full-resolution mode. The devices appear as **`HUION Huion Tablet_H640P Pen`** and **`… Pad`** |
| libwacom | supported since libwacom 1.10 (2021): `huion-h640p.tablet`, 6 express keys `BTN_0`–`BTN_5`, reversible (left-handed use) |
| X driver | **xf86-input-wacom**, forced for all Huion tablets by `/usr/share/X11/xorg.conf.d/71-nullptr-huion.conf` (upstream xf86-input-wacom 1.2.3+ does the same for every tablet) |
| Hardware | 160 × 100 mm active area (16:10), 8192 pressure levels, battery-free PW100 pen with 2 buttons |

Plug it in, then run:

```bash
tablet-info     # should say: ✔ recognised by the kernel … Tablet_H640P
tablet-setup    # applies the H640P profile below and saves it
```

**What `tablet-setup` sets for the H640P** (stored in `~/.config/nullptr/tablet.conf`, re-applied
at every login):

| Control | Setting | Notes |
|---|---|---|
| Tablet area | mapped to the laptop panel; top and bottom trimmed so 16:10 matches the 16:9 screen | circles stay round. `KEEP_ASPECT=0` uses the whole surface |
| Express key A (top) | `Ctrl+Z`: undo | LibreSprite 1.2 default shortcuts, checked in its `data/gui.xml` |
| Express key B | `Ctrl+Y`: redo | |
| Express key C | `B`: pencil | |
| Express key D | `E`: eraser | |
| Express key E | `Ctrl+=`: zoom in | |
| Express key F (bottom) | `Ctrl+-`: zoom out | |
| Pen lower button | middle click | drag to pan the canvas |
| Pen upper button | right click | paints with the background colour in LibreSprite |
| Left-handed | `tablet-setup --left-handed` | rotates the tablet 180° so the keys are on the right |
| Pressure curve | `PRESSURE_CURVE="0 0 100 100"` | only matters for apps that use pressure (not LibreSprite 1.2) |

Express-key actions use `xsetwacom` syntax, e.g. `PAD_BUTTON_3="key +space"` makes key C
"hold Space" (temporary hand tool). After editing the file, run `tablet-setup --apply`.

**Buying from AliExpress:** if `tablet-info` shows USB `256c:006d` but **not** the
`Tablet_H640P` name, the kernel didn't recognise the firmware (possibly a different
revision or a clone). Re-plug it first. If it still isn't named, send the firmware string
`tablet-info` prints; that's what Linux support depends on.

If the tablet somehow ends up on the libinput driver instead, `tablet-setup` still maps the
pen. It **disables** the express keys, which libinput would otherwise turn into mouse clicks,
and says so.

## Commands (all tablets)

### `tablet-info`

Lists tablet-vendor USB IDs, the **Huion firmware string** the kernel read, kernel devices
tagged `ID_INPUT_TABLET`, the X11 stylus/pad devices and **which driver handles each one**
(`xf86-input-wacom` or `libinput`), monitors, and libwacom's identification. It also gives an
explicit verdict for the H640P.

### `tablet-setup`

```bash
tablet-setup                    # configure (model profile if known) and save
tablet-setup --output HDMI-1    # map to another monitor (names from `xrandr` or tablet-info)
tablet-setup --left-handed      # or --right-handed
tablet-setup --show             # print the saved settings
tablet-setup --apply            # re-apply ~/.config/nullptr/tablet.conf (runs at every login)
```

Settings file (`~/.config/nullptr/tablet.conf`):

```sh
OUTPUT=eDP-1                   # monitor
KEEP_ASPECT=1                  # trim the tablet area to the monitor's aspect ratio (wacom driver)
LEFT_HANDED=0
PRESSURE_CURVE="0 0 100 100"   # xsetwacom PressureCurve (wacom driver)
PEN_BUTTON2="2"                # lower pen button (xsetwacom action), 2 = middle click
PEN_BUTTON3="3"                # upper pen button, 3 = right click
PAD_BUTTON_1="key +ctrl z -ctrl"   # express keys 1..6, top to bottom (wacom driver)
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

**NOT TESTED with a physical tablet.** No tablet was available, and the test VM's kernel has
no `uinput` support, so not even a virtual one could be created. What was verified:

- Primary sources for H640P support: Linux 6.12 `drivers/hid/hid-uclogic-*.c` (`256c:006d`),
  libwacom `data/huion-h640p.tablet` (added in libwacom 1.10), and xf86-input-wacom
  `conf/70-wacom.conf` (binds all tablets since 1.2.3).
- `tests/tablet/simulate-h640p.sh`: fake `xinput`/`xsetwacom`/`xrandr` answer like an H640P
  under both drivers. The exact commands `tablet-setup` issues (mapping, 16:9 area
  `0 1000 32000 19000`, six express keys, libinput fallback) were checked: 15/15 pass.
- With no tablet, `tablet-info` runs and `tablet-setup` says no stylus was found.

Still needs the real tablet: that the kernel names it `Tablet_H640P`, that the wacom driver
binds to it, that the keys and buttons fire, and that the cursor follows the pen correctly.
