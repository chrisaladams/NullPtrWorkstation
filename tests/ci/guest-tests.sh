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
r "~/Projects exists, owned by nullptr, no preset projects" sh -c 'test "$(stat -c %U ~/Projects)" = nullptr && touch ~/Projects/.w && rm ~/Projects/.w && [ -z "$(ls -A ~/Projects)" ]'
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
    if (n.get(\"window_properties\") or {}).get(\"class\")==\"nullptr-dev\": return ws==\"1: astro\" and n.get(\"fullscreen_mode\")==1
    return any(f(c,ws) for c in n.get(\"nodes\",[])+n.get(\"floating_nodes\",[]))
sys.exit(0 if f(t) else 1)"'

echo "--- toolchains"
for c in gcc clang clangd clang-format clang-tidy lldb lldb-dap gdb gdb-multiarch cmake ninja make bear pkg-config git nvim lazygit tree-sitter firefox-esr web libresprite tiled tiles blockbench 3d gh github-login thunar files import-assets 7z nullptr-update nullptr-iso nullptr-run-ws; do
  r "command $c" command -v "$c"
done
cc --version | head -1; lldb --version | head -1; gdb --version | head -1
r "GDB version >= 16" sh -c 'v=$(gdb --version | head -1 | grep -o "[0-9][0-9]*\.[0-9]*" | head -1); [ "${v%%.*}" -ge 16 ]'
r "JetBrainsMono Nerd Font installed" sh -c 'fc-list | grep -q "JetBrainsMono Nerd Font"'
r "AstroNvim plugins pre-installed (offline)" test -d "$HOME/.local/share/nvim/lazy/AstroNvim"
r "treesitter parsers pre-compiled" test -f "$HOME/.local/share/nvim/site/parser/c.so"

echo "--- workflow suite (includes AstroVim build/clangd/debug on CMake, Make, launch.json, .nvim.lua repos)"
bash "$T/workflow-tests.sh" 2>&1 | tee /tmp/workflow.out | sed 's/^PASS  /RESULT PASS workflow: /; s/^FAIL  /RESULT FAIL workflow: /'
cat /tmp/nwtest-editor.out 2>/dev/null | grep '^     ' | cut -c1-300
ws "1: astro"

echo "--- screenshots: AstroVim building and debugging a cloned C project"
demo="$HOME/Projects/hello-c"
mkdir -p "$demo" && git -C "$demo" init -q
cat >"$demo/main.c" <<'C'
#include <stdio.h>
#include <unistd.h>

static int score(int frame) { return frame * 10; }

int main(void) {
    int total = 0;
    for (int frame = 0; frame < 100; frame++) {
        total += score(frame);
        printf("frame %d total %d\n", frame, total);
        usleep(100000);
    }
    return 0;
}
C
printf 'cmake_minimum_required(VERSION 3.20)\nproject(hello C)\nadd_executable(hello main.c)\n' >"$demo/CMakeLists.txt"
nvr() { nvim --server "$sock" --remote-send "$1" >/dev/null 2>&1; }
tmux select-window -t dev:1; sleep 1
nvr '<C-\><C-n>:NullptrOpen '"$demo"'/main.c<CR>'; sleep 4
nvr ':NullptrBuild<CR>'; sleep 3
shot vm-02-build-in-editor   # while CMake/Ninja run in the split (it closes when the build succeeds)
sleep 15
nvr ':9<CR>'; sleep 1; nvr '<F9>'; sleep 1; nvr '<F5>'; sleep 25
# the line the running editor's debugger is stopped at (0 = not stopped); waits up to 60 s
f5_at_bp() {
  local v=""
  for _ in $(seq 1 60); do
    v="$(nvim --server "$sock" --remote-expr 'luaeval("(function() local s=require([[dap]]).session(); return s and s.current_frame and s.current_frame.line or 0 end)()")' 2>&1 | tr -d '\r\n ')"
    [ "$v" = 9 ] && { echo "debugger stopped at line $v"; return 0; }
    sleep 1
  done
  echo "debugger line after 60 s: [$v]"; return 1
}
rv "F5 in the running AstroVim stops at the breakpoint (LLDB)" f5_at_bp
shot vm-03-debugger-breakpoint
nvr '<C-\><C-n>:lua require("dap").terminate(); pcall(function() require("dapui").close() end)<CR>'; sleep 3
nvr ':enew<CR>:only<CR>'; sleep 1
tmux select-window -t dev:2

echo "--- screenshots of the installed system"
tmux select-window -t dev:1; sleep 1; nvr ':lua Snacks.dashboard()<CR>'; sleep 2
shot vm-01-editor-after-login
tmux select-window -t dev:2
art >/dev/null 2>&1; sleep 12; shot vm-04-libresprite; pkill -x libresprite

echo "--- Firefox: docs bookmarks toolbar (system policy)"
fp="$(mktemp -d)"
(timeout 60 firefox-esr --headless --no-remote --profile "$fp" about:blank >/dev/null 2>&1 &); sleep 40; pkill -f -- "--profile $fp" ; sleep 3
rv "Firefox applies the policy: docs bookmarks on the toolbar" python3 - "$fp/places.sqlite" <<'PY'
import sqlite3,sys,shutil,tempfile,os
d=tempfile.mkdtemp()
for ext in ("","-wal"):
    if os.path.exists(sys.argv[1]+ext): shutil.copy(sys.argv[1]+ext, os.path.join(d,"p.sqlite"+ext))
c=sqlite3.connect(os.path.join(d,"p.sqlite"))
rows=c.execute("select b.title,p.url from moz_bookmarks b join moz_places p on p.id=b.fk where b.parent=(select id from moz_bookmarks where guid='toolbar_____')").fetchall()
for r in rows: print("  ",r[0],"->",r[1])
titles={r[0] for r in rows}
need={"C reference","Clang","CMake tutorial","LLDB","GDB","Blockbench wiki"}
sys.exit(0 if need<=titles else 1)
PY
web https://en.cppreference.com/w/c >/dev/null 2>&1; sleep 25; shot vm-09-firefox-workspace; pkill -x firefox-esr; sleep 2

echo "--- GitHub sign-in for git (fake token, scratch home: no real account involved)"
gh_home="$(mktemp -d)"
rv "github-login sets git up to use the GitHub CLI sign-in" sh -c "HOME='$gh_home' GH_CONFIG_DIR='$gh_home/gh' GH_TOKEN=ghp_not_a_real_token github-login --no-check && HOME='$gh_home' git config --global --get-all credential.https://github.com.helper | grep -q 'gh auth git-credential'"
r "nullptr-update follows the GitHub sign-in (https)" sh -c 'nullptr-update --help | grep -q "https://github.com/chrisaladams/NullPtrWorkstation.git"'
rm -rf "$gh_home"

echo "--- file manager: thumbnails of a sprite folder"
shots=/usr/local/src/nullptr-workstation/docs/screenshots; [ -d "$shots" ] || shots="$T/tiled"
env -u I3SOCK i3-msg -q 'workspace number "7: tools"' >/dev/null 2>&1; sleep 1
files "$shots" >/dev/null 2>&1; sleep 20; shot vm-10-file-manager; pkill -x thunar; sleep 2

echo "--- Tiled: map export from the command line"
rv "Tiled exports a TMX map to JSON and CSV" bash "$T/tiled/export-test.sh"
QT_QPA_PLATFORM=offscreen tiled --version 2>/dev/null || true

echo "--- Blockbench"
dpkg-query -W -f='blockbench ${Version}\n' blockbench
3d >/dev/null 2>&1; sleep 25; shot vm-07-blockbench-workspace; pkill -f '^/opt/Blockbench/blockbench'; sleep 2
tiles "$T/tiled/room.tmx" >/dev/null 2>&1; sleep 12; shot vm-08-tiled-workspace; pkill -x tiled; sleep 2
rm -rf "$demo"
ws "1: astro"; sleep 2; shot vm-05-back-to-editor

echo "=== END nullptr guest tests"
