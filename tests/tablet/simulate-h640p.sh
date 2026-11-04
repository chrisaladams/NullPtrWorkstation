#!/usr/bin/env bash
# Logic test for tablet-setup without hardware: fake xinput/xsetwacom/xrandr answer like a
# Huion Inspiroy H640P (device names from libwacom's huion-h640p.tablet; area 32000x20000,
# i.e. 160x100 mm at 5080 lpi) on a 1920x1080 laptop panel, and every command tablet-setup
# issues is logged and checked.   Usage: tests/tablet/simulate-h640p.sh [wacom|libinput]
set -uo pipefail
driver="${1:-wacom}"
here="$(cd "$(dirname "$0")" && pwd)"; repo="$here/../.."
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
log="$tmp/calls.log"; mkdir -p "$tmp/bin" "$tmp/home"
cat >"$tmp/bin/xrandr" <<'X'
#!/bin/sh
echo "Screen 0: minimum 8 x 8, current 1920 x 1080, maximum 32767 x 32767"
echo "eDP-1 connected primary 1920x1080+0+0 (normal left inverted right x axis y axis) 276mm x 155mm"
echo "HDMI-1 disconnected (normal left inverted right x axis y axis)"
X
if [ "$driver" = wacom ]; then
cat >"$tmp/bin/xsetwacom" <<X
#!/bin/sh
echo "xsetwacom \$*" >>"$log"
case "\$1 \$2" in
  "--list devices") printf 'HUION Huion Tablet_H640P Pen stylus\tid: 12\ttype: STYLUS    \nHUION Huion Tablet_H640P Pad pad\tid: 13\ttype: PAD       \n' ;;
  "get 12") [ "\$3" = Area ] && { cat "$tmp/area" 2>/dev/null || echo "0 0 32000 20000"; } ;;
  "set 12") [ "\$3" = Area ] && echo "\$4" >"$tmp/area"; [ "\$3" = ResetArea ] && rm -f "$tmp/area" ;;
esac
exit 0
X
cat >"$tmp/bin/xinput" <<'X'
#!/bin/sh
case "$1" in
  list) case "$2" in --id-only) printf '2\n12\n13\n' ;; --name-only) case "$3" in 12) echo "HUION Huion Tablet_H640P Pen stylus";; 13) echo "HUION Huion Tablet_H640P Pad pad";; *) echo "Virtual core pointer";; esac ;;
        --short) echo "↳ dev id=$3 [slave  pointer  (2)]" ;; esac ;;
esac
X
else
cat >"$tmp/bin/xinput" <<X
#!/bin/sh
echo "xinput \$*" >>"$log"
case "\$1" in
  list) case "\$2" in
    --id-only) printf '2\n12\n13\n' ;;
    --name-only) case "\$3" in 12) echo "HUION Huion Tablet_H640P Pen";; 13) echo "HUION Huion Tablet_H640P Pad";; *) echo "Virtual core pointer";; esac ;;
    --short) echo "↳ dev id=\$3 [slave  pointer  (2)]" ;;
    13) echo "HUION Huion Tablet_H640P Pad id=13"; echo "	Buttons supported: 10" ;;
  esac ;;
esac
exit 0
X
printf '#!/bin/sh\nexit 1\n' >"$tmp/bin/xsetwacom"
fi
chmod +x "$tmp/bin/"*
out="$(HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" DISPLAY=:99 PATH="$tmp/bin:$repo/scripts/bin:$PATH" \
       "$repo/scripts/bin/tablet-setup" 2>&1)"; rc=$?
echo "$out"; echo "---- commands issued"; cat "$log"; echo "---- saved settings"; cat "$tmp/home/.config/nullptr/tablet.conf"
pass=0; fail=0
t() { if grep -qF -- "$2" "$3"; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1  (expected: $2)"; fail=$((fail+1)); fi; }
echo "---- checks ($driver driver)"
[ "$rc" = 0 ] && { echo "PASS  tablet-setup exits 0"; pass=$((pass+1)); } || { echo "FAIL  tablet-setup exit $rc"; fail=$((fail+1)); }
if [ "$driver" = wacom ]; then
  t "pen mapped to the laptop panel"            "xsetwacom set 12 MapToOutput eDP-1" "$log"
  t "16:10 area trimmed to 16:9 (centred)"      "xsetwacom set 12 Area 0 1000 32000 19000" "$log"
  t "express key A = undo"                      "xsetwacom set 13 Button 1 key +ctrl z -ctrl" "$log"
  t "express key B = redo"                      "xsetwacom set 13 Button 2 key +ctrl y -ctrl" "$log"
  t "express key C = pencil"                    "xsetwacom set 13 Button 3 key b" "$log"
  t "express key D = eraser"                    "xsetwacom set 13 Button 8 key e" "$log"
  t "express key E = zoom in"                   "xsetwacom set 13 Button 9 key +ctrl equal -ctrl" "$log"
  t "express key F = zoom out"                  "xsetwacom set 13 Button 10 key +ctrl minus -ctrl" "$log"
  t "right-handed by default"                   "xsetwacom set 12 Rotate none" "$log"
  t "settings saved with H640P profile"         "model: huion-h640p" "$tmp/home/.config/nullptr/tablet.conf"
else
  t "pen mapped to the laptop panel (libinput)" "xinput map-to-output 12 eDP-1" "$log"
  t "express keys disabled (no stray clicks)"   "xinput set-button-map 13 0 0 0 0 0 0 0 0 0 0" "$log"
  t "warning explains the libinput limitation"  "libinput driver" <(echo "$out")
fi
echo "PASS: $pass  FAIL: $fail"; [ "$fail" = 0 ]
