#!/usr/bin/env bash
# shellcheck disable=SC2088  # "~/..." appears only in human-readable test names
# Runs INSIDE the installed system, typed by the CI into tmux window 2 of the graphical
# session that started from the real tty1 login. Output goes to /dev/ttyS1, which the host
# records. Lines "RESULT PASS|FAIL name" are counted. "SCREENSHOT name" asks the host for a
# screenshot of the VM screen (it waits a few seconds after printing).
set -uo pipefail
T=/usr/local/src/nullptr-workstation/tests
r() { local name="$1"; shift; if "$@" >/tmp/r.out 2>&1; then echo "RESULT PASS $name"; else echo "RESULT FAIL $name :: $(tail -n3 /tmp/r.out | tr '\n' ' ')"; fi; }
rv() { local name="$1"; shift; if "$@" 2>&1; then echo "RESULT PASS $name"; else echo "RESULT FAIL $name"; fi; }  # verbose
shot() { echo "SCREENSHOT $1"; sleep 6; }
ws() { env -u I3SOCK i3-msg -q "workspace number $1" >/dev/null 2>&1; sleep 2; }
sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nullptr-nvim-$(id -u).sock"

echo "=== BEGIN nullptr guest tests"
echo "--- system"
echo "debian $(cat /etc/debian_version)  kernel $(uname -r)  user $(id)"
r "running as user nullptr" test "$(id -un)" = nullptr
r "home is /home/nullptr" test "$(getent passwd nullptr | cut -d: -f6)" = /home/nullptr
r "nullptr is in group sudo" sh -c 'id -nG | grep -qw sudo'
r "sudo asks for a password (no NOPASSWD)" sh -c '! sudo -n true'
r "no live-boot/live-config left in the installed system" sh -c '! dpkg -s live-boot >/dev/null 2>&1 && ! dpkg -s live-config >/dev/null 2>&1'
r "~/Projects starter projects present" test -f "$HOME/Projects/raylib-hello/src/main.c" -a -f "$HOME/Projects/gameboy-hello/Makefile"
r "~/Projects owned by nullptr and writable" sh -c 'test "$(stat -c %U ~/Projects/raylib-hello/src/main.c)" = nullptr && touch ~/Projects/.w && rm ~/Projects/.w'
r "NetworkManager running (nmtui available)" sh -c 'systemctl is-active --quiet NetworkManager && command -v nmtui'
r "TLP enabled, power-profiles-daemon absent" sh -c 'systemctl is-enabled --quiet tlp && ! systemctl is-active --quiet power-profiles-daemon'
r "PipeWire running for the user" sh -c 'systemctl --user is-active --quiet pipewire || pgrep -x pipewire'

echo "--- graphical session (started by the tty1 login)"
r "Xorg running on tty1" sh -c 'ps -o tty= -C Xorg | grep -q tty1'
r "i3 running" pgrep -x i3
r "kitty (nullptr-dev) running" pgrep -f 'kitty --class nullptr-dev'
r "tmux session dev with windows 1-5" sh -c '[ "$(tmux list-windows -t dev -F "#I:#W" | head -5 | tr "\n" " ")" = "1:editor 2:build 3:lazygit 4:shell 5:btop " ]'
r "AstroVim running in window 1" sh -c "nvim --server '$sock' --remote-expr 1 2>&1 | grep -q 1"
r "AstroVim shows the dashboard" sh -c "nvim --server '$sock' --remote-expr '&filetype' 2>&1 | grep -q snacks_dashboard"
r "kitty is fullscreen on workspace 1" sh -c 'env -u I3SOCK i3-msg -t get_tree | python3 -c "
import json,sys
t=json.load(sys.stdin)
def f(n,ws=None):
    if n.get(\"type\")==\"workspace\": ws=n[\"name\"]
    if (n.get(\"window_properties\") or {}).get(\"class\")==\"nullptr-dev\": return ws==\"1: code\" and n.get(\"fullscreen_mode\")==1
    return any(f(c,ws) for c in n.get(\"nodes\",[])+n.get(\"floating_nodes\",[]))
sys.exit(0 if f(t) else 1)"'

echo "--- toolchains"
gb-info
for c in gcc clang clangd clang-format clang-tidy gdb cmake ninja make pkg-config git nvim lazygit tree-sitter libresprite emulicious codium java; do
  r "command $c" command -v "$c"
done
r "GDB version >= 16" sh -c 'v=$(gdb --version | head -1 | grep -o "[0-9][0-9]*\.[0-9]*" | head -1); [ "${v%%.*}" -ge 16 ]'
r "raylib 5.5 via pkg-config" sh -c 'pkg-config --modversion raylib | grep -q "^5\.5"'
r "GBDK 4.5.0 lcc" test -x /opt/gbdk/bin/lcc
r "Emulicious installed" test -f /opt/emulicious/Emulicious.jar
r "JetBrainsMono Nerd Font installed" sh -c 'fc-list | grep -q "JetBrainsMono Nerd Font"'
r "AstroNvim plugins pre-installed (offline)" test -d "$HOME/.local/share/nvim/lazy/AstroNvim"
r "treesitter parsers pre-compiled" test -f "$HOME/.local/share/nvim/site/parser/c.so"

echo "--- workflow suite"
bash "$T/workflow-tests.sh" 2>&1 | sed 's/^PASS  /RESULT PASS workflow: /; s/^FAIL  /RESULT FAIL workflow: /'
projects use raylib-hello >/dev/null 2>&1

echo "--- raylib: GDB through nvim-dap"
rv "raylib C breakpoint, variables, step, continue (GDB + nvim-dap)" bash "$T/dap/raylib-dap-test.sh"
ws "1: code"

echo "--- Game Boy: Emulicious debug adapter"
rv "Game Boy C breakpoint, variables, step, continue (Emulicious DAP)" bash "$T/dap/gameboy-dap-test.sh"
sleep 2; pkill -f Emulicious.jar; ws "1: code"

echo "--- screenshots of the installed system"
shot vm-01-editor-after-login
(run-game raylib-hello >/dev/null 2>&1 &) ; sleep 12; shot vm-02-raylib-running; pkill -x raylib-hello; sleep 2
projects use gameboy-hello >/dev/null 2>&1
gb-run gameboy-hello >/dev/null 2>&1; sleep 25
r "Emulicious window opens with the ROM" sh -c 'xdotool search --name "[Ee]mulicious" | grep -q . || xdotool search --class "[Ee]mulicious" | grep -q .'
shot vm-03-gameboy-emulicious
pkill -f Emulicious.jar; sleep 2
art >/dev/null 2>&1; sleep 12; shot vm-04-libresprite; pkill -x libresprite
projects use raylib-hello >/dev/null 2>&1
ws "1: code"; sleep 2; shot vm-05-back-to-editor

echo "=== END nullptr guest tests"
