#!/usr/bin/env bash
# nullptr Workstation — workflow test-suite.
# Run as the workstation user inside the graphical session (DISPLAY set), e.g.:
#   tests/workflow-tests.sh            # prints PASS/FAIL per test, exit 1 on any FAIL
# Creates and removes scratch projects named nwtest-*; never touches other projects.
set -uo pipefail
P="$HOME/Projects"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/nullptr/active-project"
pass=0; fail=0; results=()
ok()   { results+=("PASS  $1"); pass=$((pass+1)); }
bad()  { results+=("FAIL  $1${2:+  — $2}"); fail=$((fail+1)); }
check(){ local name="$1"; shift; if "$@" >/tmp/nwtest.out 2>&1; then ok "$name"; else bad "$name" "$(tail -n2 /tmp/nwtest.out | tr '\n' ' ')"; fi; }
cleanup() { rm -rf "$P"/nwtest-*; }
cleanup; trap cleanup EXIT
saved_active="$(cat "$STATE" 2>/dev/null || true)"

# ---------------------------------------------------------------- templates
check "new-raylib creates project"        new-raylib nwtest-pirates
check "new-raylib project builds"         build nwtest-pirates
check "raylib Debug binary exists"        test -x "$P/nwtest-pirates/build/debug/nwtest-pirates"
check "compile_commands.json linked"      test -f "$P/nwtest-pirates/compile_commands.json"
check "build --release works"             build --release nwtest-pirates
check "Release binary exists"             test -x "$P/nwtest-pirates/build/release/nwtest-pirates"
echo "// my edit" >>"$P/nwtest-pirates/src/main.c"
sum_before="$(sha256sum "$P/nwtest-pirates/src/main.c")"
if new-raylib nwtest-pirates >/tmp/nwtest.out 2>&1; then bad "new-raylib refuses existing name"; else ok "new-raylib refuses existing name"; fi
check "existing project left untouched"   test "$sum_before" = "$(sha256sum "$P/nwtest-pirates/src/main.c")"
if new-raylib '../evil' >/dev/null 2>&1; then bad "invalid project name rejected"; else ok "invalid project name rejected"; fi
check "new-gameboy creates project"       new-gameboy nwtest-kingdom-gb
check "gb-build builds the ROM"           gb-build nwtest-kingdom-gb
check "Debug ROM + .cdb exist"            test -s "$P/nwtest-kingdom-gb/build/debug/nwtest-kingdom-gb.gb" -a -s "$P/nwtest-kingdom-gb/build/debug/nwtest-kingdom-gb.cdb"
check ".cdb has C line records"           grep -q '^L:C\$main.c\$' "$P/nwtest-kingdom-gb/build/debug/nwtest-kingdom-gb.cdb"
check "ROM header title set"              sh -c "dd if='$P/nwtest-kingdom-gb/build/debug/nwtest-kingdom-gb.gb' bs=1 skip=308 count=15 2>/dev/null | grep -q NWTEST_KINGDOM"
check "gb-build --release"                gb-build --release nwtest-kingdom-gb
check "gb-clean removes build/"           sh -c "gb-clean nwtest-kingdom-gb && test ! -d '$P/nwtest-kingdom-gb/build'"
if gb-build nwtest-pirates >/dev/null 2>&1; then bad "gb-build rejects raylib project"; else ok "gb-build rejects raylib project"; fi
check "new projects are git repositories" git -C "$P/nwtest-kingdom-gb" rev-parse --git-dir

# ---------------------------------------------------------------- generic (plain C) projects
check "new-c creates a plain C project"          new-c nwtest-tool --no-git
check "--no-git skips git init"                  sh -c "! test -e '$P/nwtest-tool/.git'"
check "new-c project has its own CMakeLists"     grep -q 'add_executable' "$P/nwtest-tool/CMakeLists.txt"
check "generic project builds (CMake)"           build nwtest-tool
check "run-game runs a generic program in the terminal" sh -c "run-game nwtest-tool 2>&1 | grep -q 'Hello from nwtest-tool!'"
check "build --clean removes build output"       sh -c "build --clean nwtest-tool && test ! -d '$P/nwtest-tool/build'"
mkdir -p "$P/nwtest-mk"
printf 'all:\n\tcc -g -o hello hello.c\nclean:\n\trm -f hello\n' >"$P/nwtest-mk/Makefile"
printf '#include <stdio.h>\nint main(void){puts("make ok");return 0;}\n' >"$P/nwtest-mk/hello.c"
check "projects adopt marks an existing folder"  projects adopt "$P/nwtest-mk"
check "adopted plain folder is generic"          grep -qx 'type=generic' "$P/nwtest-mk/.nullptr-project"
if projects adopt "$P/nwtest-mk" >/dev/null 2>&1; then bad "adopt refuses an existing project"; else ok "adopt refuses an existing project"; fi
echo 'artifact=hello' >>"$P/nwtest-mk/.nullptr-project"
check "generic Makefile project builds and runs" sh -c "run-game nwtest-mk 2>&1 | grep -q 'make ok'"
echo 'run=echo custom-run-$CONFIG' >>"$P/nwtest-mk/.nullptr-project"
check "run= line in .nullptr-project is used"     sh -c "run-game nwtest-mk 2>&1 | grep -q custom-run-debug"
check "generic project listed by projects"       sh -c "projects list | grep -q 'nwtest-mk  *generic'"

# ---------------------------------------------------------------- project selection
cd "$HOME" || exit 1
check "projects use raylib-hello"         projects use raylib-hello
build >/tmp/nwtest.out 2>&1; grep -q "raylib-hello" /tmp/nwtest.out && grep -q "(raylib" /tmp/nwtest.out && ok "build (from ~) uses active raylib project" || bad "build (from ~) uses active raylib project"
check "projects use gameboy-hello"        projects use gameboy-hello
build >/tmp/nwtest.out 2>&1; grep -q "gameboy-hello" /tmp/nwtest.out && grep -q "gameboy-hello.gb" /tmp/nwtest.out && ok "build (from ~) follows switch to Game Boy" || bad "build (from ~) follows switch to Game Boy"
cd "$P/raylib-hello/src" || exit 1
build >/tmp/nwtest.out 2>&1; rc=$?
[ "$rc" = 2 ] && grep -q "Refusing to guess" /tmp/nwtest.out && ok "conflict (cwd A, active B) refuses instead of guessing" || bad "conflict (cwd A, active B) refuses instead of guessing" "rc=$rc"
check "explicit project name wins"        build raylib-hello
cd "$HOME" || exit 1
check "projects list shows active (*)"    sh -c "projects list | grep -q '^ \* gameboy-hello'"

# AstroVim: entering a file of another project makes it active (shared with the shell)
projects use gameboy-hello >/dev/null 2>&1
nvim --headless -c "edit $P/raylib-hello/src/main.c" -c "sleep 300m" -c "qa!" >/dev/null 2>&1
[ "$(cat "$STATE")" = "$P/raylib-hello" ] && ok "AstroVim file switch updates active project" || bad "AstroVim file switch updates active project" "active=$(cat "$STATE")"
build >/tmp/nwtest.out 2>&1; grep -q "(raylib" /tmp/nwtest.out && ok "shell build follows AstroVim's project" || bad "shell build follows AstroVim's project"

# ---------------------------------------------------------------- login autostart guard (logic only)
guard() { # guard VAR=VAL ... -> prints yes/no   (bash increments SHLVL: 0 here = a fresh login shell)
  env -i HOME="$HOME" PATH="$PATH" "$@" bash --norc --noprofile -i -c '
    tty() { echo "${FAKE_TTY:-/dev/pts/9}"; }; export -f tty
    eval "$(sed -n "/^nullptr_autostart_ok()/,/^}/p" "$HOME/.bash_profile")"
    nullptr_autostart_ok && echo yes || echo no' 2>/dev/null | tail -n1
}
[ "$(guard FAKE_TTY=/dev/tty1 XDG_VTNR=1 SHLVL=0)" = yes ] && ok "autostart: local login on tty1 starts X" || bad "autostart: local login on tty1 starts X"
[ "$(guard FAKE_TTY=/dev/tty2 XDG_VTNR=2 SHLVL=0)" = no ]  && ok "autostart: tty2 stays text (recovery console)" || bad "autostart: tty2 stays text (recovery console)"
[ "$(guard FAKE_TTY=/dev/tty1 XDG_VTNR=1 SHLVL=0 SSH_CONNECTION='1 2 3 4')" = no ] && ok "autostart: never for SSH" || bad "autostart: never for SSH"
[ "$(guard FAKE_TTY=/dev/tty1 XDG_VTNR=1 SHLVL=0 TMUX=/tmp/x)" = no ] && ok "autostart: never inside tmux" || bad "autostart: never inside tmux"
[ "$(guard FAKE_TTY=/dev/tty1 XDG_VTNR=1 SHLVL=1)" = no ] && ok "autostart: never for nested shells" || bad "autostart: never for nested shells"
[ "$(guard FAKE_TTY=/dev/tty1 XDG_VTNR=1 SHLVL=0 DISPLAY=:0)" = no ] && ok "autostart: not when X already running" || bad "autostart: not when X already running"
mkdir -p "$HOME/.config/nullptr"; touch "$HOME/.config/nullptr/no-autostart"
[ "$(guard FAKE_TTY=/dev/tty1 XDG_VTNR=1 SHLVL=0)" = no ] && ok "autostart: ~/.config/nullptr/no-autostart disables X" || bad "autostart: ~/.config/nullptr/no-autostart disables X"
rm -f "$HOME/.config/nullptr/no-autostart"

# X fails to start -> the user is left in a working text shell with recovery hints
fakebin="$(mktemp -d)"; printf '#!/bin/sh\necho "Fatal server error: no screens found" >&2\nexit 1\n' >"$fakebin/startx"; chmod +x "$fakebin/startx"
out="$(env -i HOME="$HOME" PATH="$fakebin:$PATH" XDG_VTNR=1 SHLVL=0 TERM=dumb bash --noprofile --norc -i -c '
  tty() { echo /dev/tty1; }; export -f tty
  . "$HOME/.bash_profile"; echo "SHELL-STILL-ALIVE"' 2>&1)"
echo "$out" | grep -q "graphical session failed" && echo "$out" | grep -q "SHELL-STILL-ALIVE" && echo "$out" | grep -q "helpme recovery" \
  && ok "X failure falls back to text console with recovery hints" || bad "X failure falls back to text console with recovery hints"
rm -rf "$fakebin"

# ---------------------------------------------------------------- asset packs (import-assets)
check "new-c for asset import"           new-c nwtest-assets --no-git
ad="$(mktemp -d)"
python3 - "$ad" <<'PY'
import zipfile,sys,os
d=sys.argv[1]; png=b"\x89PNG\r\n\x1a\n"+b"0"*32
with zipfile.ZipFile(os.path.join(d,"Dungeon Pack.zip"),"w") as z:
    z.writestr("Dungeon Pack/tiles/floor.png",png); z.writestr("Dungeon Pack/sfx/door.wav",b"RIFF")
    z.writestr("Dungeon Pack/LICENSE.txt","CC-BY 4.0"); z.writestr("__MACOSX/._junk","x")
with zipfile.ZipFile(os.path.join(d,"evil.zip"),"w") as z:
    z.writestr("../../nwtest-escaped.txt","x"); z.writestr("ok.png",png)
PY
check "import-assets unpacks a zip"      import-assets "$ad/Dungeon Pack.zip" --project nwtest-assets --url https://example.itch.io/dungeon
check "wrapping folder flattened"        test -f "$P/nwtest-assets/assets/Dungeon-Pack/tiles/floor.png" -a -f "$P/nwtest-assets/assets/Dungeon-Pack/sfx/door.wav"
check "macOS clutter dropped"            test ! -e "$P/nwtest-assets/assets/Dungeon-Pack/__MACOSX"
check "CREDITS.md names pack, URL, license" sh -c "grep -q 'Dungeon-Pack.*example.itch.io.*LICENSE.txt' '$P/nwtest-assets/CREDITS.md'"
if import-assets "$ad/Dungeon Pack.zip" --project nwtest-assets >/dev/null 2>&1; then bad "import-assets refuses to overwrite"; else ok "import-assets refuses to overwrite"; fi
import-assets "$ad/evil.zip" --project nwtest-assets >/dev/null 2>&1
check "pack paths cannot escape assets/" sh -c "test ! -e /nwtest-escaped.txt && [ -z \"\$(find /tmp \"\$HOME\" -name nwtest-escaped.txt -not -path '*/assets/evil/*' 2>/dev/null)\" ]"
rm -rf "$ad"

# ---------------------------------------------------------------- tools
check "GBDK_HOME exported by /etc/profile.d" bash -lc '[ "$GBDK_HOME" = /opt/gbdk ]'
check "lcc on PATH for login shells"     bash -lc 'command -v lcc'
check "tablet-info runs without a tablet" tablet-info
check "keys prints the cheat sheet"      sh -c 'keys | grep -q "Ctrl+b"'
check "helpme prints the guide"          sh -c 'helpme | grep -qi "projects"'
if [ -n "${DISPLAY:-}" ]; then
  pkill -x libresprite 2>/dev/null; for _ in $(seq 1 20); do pgrep -x libresprite >/dev/null || break; sleep 0.5; done
  check "art launches LibreSprite"        art
  for _ in $(seq 1 20); do xdotool search --class libresprite >/dev/null 2>&1 && break; sleep 1; done
  check "LibreSprite window appears"      sh -c 'xdotool search --class libresprite | grep -q .'
  ws="$(i3-msg -t get_tree | python3 -c 'import json,sys
t=json.load(sys.stdin)
def w(n,ws=None):
    if n.get("type")=="workspace": ws=n["name"]
    if (n.get("window_properties") or {}).get("class","").lower()=="libresprite": print(ws); return True
    return any(w(c,ws) for c in n.get("nodes",[])+n.get("floating_nodes",[]))
w(t)')"
  [ "$ws" = "3: libresprite" ] && ok "LibreSprite lands on workspace 3 (libresprite)" || bad "LibreSprite lands on workspace 3 (libresprite)" "ws=$ws"
  art >/dev/null 2>&1; sleep 2
  [ "$(pgrep -c -x libresprite)" = 1 ] && ok "art again focuses, no duplicate" || bad "art again focuses, no duplicate" "count=$(pgrep -c -x libresprite)"
  # Firefox: workspace 2 (firefox), focus-or-launch like art (skipped where Firefox isn't installed)
  if command -v firefox-esr >/dev/null 2>&1; then
    ffwin() { i3-msg -t get_tree | python3 -c 'import json,sys
t=json.load(sys.stdin); out=[]
def w(n,ws=None):
    if n.get("type")=="workspace": ws=n["name"]
    if (n.get("window_properties") or {}).get("class","").lower().startswith("firefox"): out.append(ws)
    for c in n.get("nodes",[])+n.get("floating_nodes",[]): w(c,ws)
w(t); print(len(out), out[0] if out else "")'; }
    pkill -x firefox-esr 2>/dev/null; sleep 2
    check "web launches Firefox"            web
    for _ in $(seq 1 90); do [ "$(ffwin | cut -d' ' -f1)" -ge 1 ] && break; sleep 1; done
    fw="$(ffwin)"
    [ "${fw#* }" = "2: firefox" ] && ok "Firefox lands on workspace 2 (firefox)" || bad "Firefox lands on workspace 2 (firefox)" "found=$fw"
    web >/dev/null 2>&1; sleep 3
    [ "$(ffwin | cut -d' ' -f1)" = 1 ] && ok "web again focuses Firefox, no second window" || bad "web again focuses Firefox, no second window" "found=$(ffwin)"
    pkill -x firefox-esr 2>/dev/null; sleep 2
  fi
  # Tiled: its own workspace (4: tiled), focus-or-launch like art
  pkill -x tiled 2>/dev/null; for _ in $(seq 1 20); do pgrep -x tiled >/dev/null || break; sleep 0.5; done
  check "tiles launches Tiled"            tiles
  for _ in $(seq 1 40); do xdotool search --class '^tiled$' >/dev/null 2>&1 && break; sleep 1; done
  check "Tiled window appears"            sh -c 'xdotool search --class "^tiled$" | grep -q .'
  tws="$(i3-msg -t get_tree | python3 -c 'import json,sys
t=json.load(sys.stdin)
def w(n,ws=None):
    if n.get("type")=="workspace": ws=n["name"]
    if (n.get("window_properties") or {}).get("class","").lower()=="tiled": print(ws); return True
    return any(w(c,ws) for c in n.get("nodes",[])+n.get("floating_nodes",[]))
w(t)')"
  [ "$tws" = "4: tiled" ] && ok "Tiled lands on workspace 4 (tiled)" || bad "Tiled lands on workspace 4 (tiled)" "ws=$tws"
  tiles >/dev/null 2>&1; sleep 2
  [ "$(pgrep -c -x tiled)" = 1 ] && ok "tiles again focuses Tiled, no duplicate" || bad "tiles again focuses Tiled, no duplicate" "count=$(pgrep -c -x tiled)"
  pkill -x tiled 2>/dev/null; sleep 1
  # Blender: its own workspace (5: blender), focus-or-launch like art
  pkill -x blender 2>/dev/null; for _ in $(seq 1 20); do pgrep -x blender >/dev/null || break; sleep 0.5; done
  check "3d launches Blender"             3d
  for _ in $(seq 1 60); do xdotool search --class '^Blender$' >/dev/null 2>&1 && break; sleep 1; done
  check "Blender window appears"          sh -c 'xdotool search --class "^Blender$" | grep -q .'
  bws="$(i3-msg -t get_tree | python3 -c 'import json,sys
t=json.load(sys.stdin)
def w(n,ws=None):
    if n.get("type")=="workspace": ws=n["name"]
    if (n.get("window_properties") or {}).get("class","")=="Blender": print(ws); return True
    return any(w(c,ws) for c in n.get("nodes",[])+n.get("floating_nodes",[]))
w(t)')"
  [ "$bws" = "5: blender" ] && ok "Blender lands on workspace 5 (blender)" || bad "Blender lands on workspace 5 (blender)" "ws=$bws"
  3d >/dev/null 2>&1; sleep 2
  [ "$(pgrep -c -x blender)" = 1 ] && ok "3d again focuses Blender, no duplicate" || bad "3d again focuses Blender, no duplicate" "count=$(pgrep -c -x blender)"
  pkill -x blender 2>/dev/null; sleep 1
  # file manager: floats over the current workspace
  if command -v thunar >/dev/null 2>&1; then
    i3-msg -q 'workspace number "7: tools"' >/dev/null 2>&1; sleep 1
    check "files opens Thunar"            files "$P"
    for _ in $(seq 1 30); do xdotool search --class '^Thunar$' >/dev/null 2>&1 && break; sleep 1; done
    tf="$(i3-msg -t get_tree | python3 -c 'import json,sys
t=json.load(sys.stdin)
def w(n,ws=None,fl=False):
    if n.get("type")=="workspace": ws=n["name"]
    if (n.get("window_properties") or {}).get("class","")=="Thunar": print(ws, "floating" if fl else "tiled"); return True
    return any(w(c,ws,fl) for c in n.get("nodes",[])) or any(w(c,ws,True) for c in n.get("floating_nodes",[]))
w(t)')"
    [ "$tf" = "7: tools floating" ] && ok "Thunar floats on the current workspace" || bad "Thunar floats on the current workspace" "found=$tf"
    check "file manager sidebar has Projects and Downloads" sh -c 'grep -q "/Projects Projects" ~/.config/gtk-3.0/bookmarks && grep -q "/Downloads Downloads" ~/.config/gtk-3.0/bookmarks'
    pkill -x thunar 2>/dev/null; sleep 1
  fi
  check "tablet-setup handles no tablet gracefully" sh -c 'tablet-setup 2>&1 | grep -q "No stylus"'
fi

[ -n "$saved_active" ] && projects use "$saved_active" >/dev/null 2>&1
printf '%s\n' "${results[@]}"
echo "----"
echo "PASS: $pass  FAIL: $fail"
[ "$fail" = 0 ]
