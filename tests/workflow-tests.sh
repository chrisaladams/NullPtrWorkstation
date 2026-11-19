#!/usr/bin/env bash
# nullptr Workstation — workflow test-suite.
# Run as the workstation user inside the graphical session (DISPLAY set), e.g.:
#   tests/workflow-tests.sh            # prints PASS/FAIL per test, exit 1 on any FAIL
# Creates and removes scratch folders named nwtest-* in ~/Projects; never touches others.
set -uo pipefail
P="$HOME/Projects"
T="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/nullptr"
pass=0; fail=0; results=()
ok()   { results+=("PASS  $1"); pass=$((pass+1)); }
bad()  { results+=("FAIL  $1${2:+  — $2}"); fail=$((fail+1)); }
check(){ local name="$1"; shift; if "$@" >/tmp/nwtest.out 2>&1; then ok "$name"; else bad "$name" "$(tail -n2 /tmp/nwtest.out | tr '\n' ' ')"; fi; }
cleanup() { rm -rf "$P"/nwtest-*; }
mkdir -p "$P"; cleanup; trap cleanup EXIT
# workspace of the first window whose class matches the regex (case-insensitive)
wsof() { i3-msg -t get_tree | python3 -c 'import json,re,sys
t=json.load(sys.stdin); rx=re.compile(sys.argv[1],re.I)
def w(n,ws=None):
    if n.get("type")=="workspace": ws=n["name"]
    if rx.search((n.get("window_properties") or {}).get("class") or ""): print(ws); return True
    return any(w(c,ws) for c in n.get("nodes",[])+n.get("floating_nodes",[]))
w(t)' "$1"; }
focused_ws() { i3-msg -t get_workspaces | python3 -c 'import json,sys; print([w["name"] for w in json.load(sys.stdin) if w["focused"]][0])'; }

# ---------------------------------------------------------------- C toolchain (clang default)
check "cc is clang"                       sh -c 'cc --version | head -1 | grep -qi clang'
check "c++ is clang++"                    sh -c 'c++ --version | head -1 | grep -qi clang'
tc="$(mktemp -d)"; printf 'cmake_minimum_required(VERSION 3.20)\nproject(t C)\nadd_executable(t t.c)\n' >"$tc/CMakeLists.txt"; echo 'int main(void){return 0;}' >"$tc/t.c"
check "CMake picks Clang by default"      sh -c "cmake -S '$tc' -B '$tc/b' -G Ninja | grep -q 'C compiler identification is Clang'"
rm -rf "$tc"
check "lldb-dap available (AstroVim's debugger)" sh -c 'timeout 10 lldb-dap --help </dev/null 2>&1 | grep -qi "dap"'
check "gdb >= 14 (built-in DAP)"          sh -c 'v=$(gdb --version | head -1 | grep -o "[0-9][0-9]*\.[0-9]*" | head -1); [ "${v%%.*}" -ge 14 ]'
check "gdb-multiarch for other CPUs (ARM)" sh -c 'gdb-multiarch -batch -ex "set architecture arm" 2>&1 | grep -qi "arm"'
check "bear writes compile_commands.json for Make" command -v bear
for c in build run-game debug-game projects new-c new-raylib new-gameboy gb-build lcc emulicious codium blender; do
  if command -v "$c" >/dev/null 2>&1; then bad "no '$c' any more (removed)" "$(command -v "$c")"; else ok "no '$c' any more (removed)"; fi
done
check "no raylib installed system-wide"   sh -c '! pkg-config --exists raylib && test ! -e /usr/local/include/raylib.h'

# ---------------------------------------------------------------- a project from GitHub (simulated by a local repository)
up="$(mktemp -d)"
git -C "$up" init -q -b main 2>/dev/null || git -C "$up" init -q
printf '#include <stdio.h>\nint main(void){puts("cloned ok");return 0;}\n' >"$up/main.c"
printf 'cmake_minimum_required(VERSION 3.20)\nproject(game C)\nadd_executable(game main.c)\n' >"$up/CMakeLists.txt"
git -C "$up" add -A && git -C "$up" -c user.name=t -c user.email=t@t commit -qm init
check "git clone --recurse-submodules into ~/Projects" git clone -q --recurse-submodules "$up" "$P/nwtest-game"
check "a cloned CMake project builds with plain cmake" sh -c "cd '$P/nwtest-game' && cmake -S . -B build -G Ninja >/dev/null && cmake --build build >/dev/null && ./build/game | grep -q 'cloned ok'"
rm -rf "$up"
# AstroVim records the project you open; the terminal tools follow it
nvim --headless -c "lua require('nullptr.project').open('$P/nwtest-game/main.c')" -c "sleep 300m" -c "qa!" >/dev/null 2>&1
[ "$(cat "$STATE/editor-cwd" 2>/dev/null)" = "$P/nwtest-game" ] && ok "AstroVim records the open project (tools follow it)" || bad "AstroVim records the open project (tools follow it)" "editor-cwd=$(cat "$STATE/editor-cwd" 2>/dev/null)"
check "tmux status shows the pane's repository" sh -c "nullptr-tmux-status '$P/nwtest-game' | grep -q 'nwtest-game'"

# ---------------------------------------------------------------- AstroVim: build, clangd, debug (CMake / Make / launch.json / .nvim.lua)
bash "$T/editor/run-editor-tests.sh" >/tmp/nwtest-editor.out 2>&1
while IFS= read -r l; do
  case "$l" in "PASS editor: "*) ok "${l#PASS }" ;; "FAIL editor: "*) bad "${l#FAIL }" ;; esac
done </tmp/nwtest-editor.out
grep -q '^\(PASS\|FAIL\) editor: ' /tmp/nwtest-editor.out || bad "editor tests produced no result" "$(tail -n3 /tmp/nwtest-editor.out | tr '\n' ' ')"

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
mkdir -p "$P/nwtest-assets" && git -C "$P/nwtest-assets" init -q
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
check "import-assets unpacks a zip"      import-assets "$ad/Dungeon Pack.zip" --to nwtest-assets --url https://example.itch.io/dungeon
check "wrapping folder flattened"        test -f "$P/nwtest-assets/assets/Dungeon-Pack/tiles/floor.png" -a -f "$P/nwtest-assets/assets/Dungeon-Pack/sfx/door.wav"
check "macOS clutter dropped"            test ! -e "$P/nwtest-assets/assets/Dungeon-Pack/__MACOSX"
check "CREDITS.md names pack, URL, license" sh -c "grep -q 'Dungeon-Pack.*example.itch.io.*LICENSE.txt' '$P/nwtest-assets/CREDITS.md'"
if import-assets "$ad/Dungeon Pack.zip" --to nwtest-assets >/dev/null 2>&1; then bad "import-assets refuses to overwrite"; else ok "import-assets refuses to overwrite"; fi
import-assets "$ad/evil.zip" --to nwtest-assets >/dev/null 2>&1
check "pack paths cannot escape assets/" sh -c "test ! -e /nwtest-escaped.txt && [ -z \"\$(find /tmp \"\$HOME\" -name nwtest-escaped.txt -not -path '*/assets/evil/*' 2>/dev/null)\" ]"
check "import-assets uses the repository you are in" sh -c "cd '$P/nwtest-assets' && import-assets '$ad/Dungeon Pack.zip' --name from-cwd && test -d '$P/nwtest-assets/assets/from-cwd'"
rm -rf "$ad"

# ---------------------------------------------------------------- tools
check "tablet-info runs without a tablet" tablet-info
check "keys prints the cheat sheet"      sh -c 'keys | grep -q "Ctrl+b"'
check "helpme prints the guide"          sh -c 'helpme | grep -qi "clone"'
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
  # Blockbench: workspace 5 (blockbench), focus-or-launch like art
  pkill -f '^/opt/Blockbench/blockbench' 2>/dev/null; sleep 2
  check "3d launches Blockbench"          3d
  for _ in $(seq 1 60); do xdotool search --class 'blockbench' >/dev/null 2>&1 && break; sleep 1; done
  check "Blockbench window appears"       sh -c 'xdotool search --class "blockbench" | grep -q .'
  bws="$(wsof '^net\.blockbench\.blockbench$')"
  [ "$bws" = "5: blockbench" ] && ok "Blockbench lands on workspace 5 (blockbench)" || bad "Blockbench lands on workspace 5 (blockbench)" "ws=$bws"
  3d >/dev/null 2>&1; sleep 3
  n="$(i3-msg -t get_tree | grep -o '"class":"net.blockbench.blockbench"' | wc -l)"
  [ "$n" = 1 ] && ok "3d again focuses Blockbench, no second window" || bad "3d again focuses Blockbench, no second window" "windows=$n"
  pkill -f '^/opt/Blockbench/blockbench' 2>/dev/null; sleep 2
  # a program window started from the editor workspace goes to "6: run"; back to 1 when it closes
  pgrep -u "$(id -u)" -f nullptr-run-ws >/dev/null || (nullptr-run-ws >/dev/null 2>&1 &)
  i3-msg -q 'workspace number "1: astro"'; sleep 1
  xmessage -name nwtest-run "a program window" & xm=$!
  for _ in $(seq 1 20); do [ -n "$(wsof '^xmessage$')" ] && break; sleep 0.5; done; sleep 1
  rws="$(wsof '^xmessage$')"; fws="$(focused_ws)"
  [ "$rws" = "6: run" ] && [ "$fws" = "6: run" ] && ok "a program started on workspace 1 opens on workspace 6 (run), shown" || bad "a program started on workspace 1 opens on workspace 6 (run), shown" "window=$rws focused=$fws"
  kill $xm 2>/dev/null; sleep 2
  [ "$(focused_ws)" = "1: astro" ] && ok "closing it returns to the editor (workspace 1)" || bad "closing it returns to the editor (workspace 1)" "focused=$(focused_ws)"
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

printf '%s\n' "${results[@]}"
echo "----"
echo "PASS: $pass  FAIL: $fail"
[ "$fail" = 0 ]
