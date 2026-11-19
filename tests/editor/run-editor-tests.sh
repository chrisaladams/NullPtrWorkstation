#!/usr/bin/env bash
# Builds four small C repositories the way you would clone them (nothing workstation-specific
# inside), then drives AstroVim headless: Space m b, clangd, F5 with a breakpoint.
#   1 cmake       plain CMake            -> CMake+Ninja, LLDB (default)
#   2 make        plain Makefile         -> make via bear, LLDB (default)
#   3 launchjson  .vscode/launch.json    -> the project's GDB configuration
#   4 nvimlua     .nvim.lua build/debug  -> the project's own build command and debugger
# Prints "PASS name" / "FAIL name :: report" lines. Needs the AstroNvim config + plugins.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
fails=0

src='#include <stdio.h>

static int step(int frame) { return frame * 2; }

int main(void) {
    int frame = 0;
    for (int i = 0; i < 5; i++) {
        frame = step(i);
        printf("frame %d\n", frame);
    }
    return 0;
}'
bp_line=8  # frame = step(i);

mkrepo() { mkdir -p "$work/$1"; printf '%s\n' "$src" >"$work/$1/main.c"; git -C "$work/$1" init -q; }

mkrepo cmake
printf 'cmake_minimum_required(VERSION 3.20)\nproject(counter C)\nadd_executable(counter main.c)\n' >"$work/cmake/CMakeLists.txt"

mkrepo make
printf 'CFLAGS ?= -g -O0 -Wall\ncounter: main.c\n\t$(CC) $(CFLAGS) -o $@ main.c\nclean:\n\trm -f counter\n' >"$work/make/Makefile"

mkrepo launchjson
printf 'cmake_minimum_required(VERSION 3.20)\nproject(counter C)\nadd_executable(counter main.c)\n' >"$work/launchjson/CMakeLists.txt"
mkdir -p "$work/launchjson/.vscode"
cat >"$work/launchjson/.vscode/launch.json" <<'J'
{
  "version": "0.2.0",
  "configurations": [
    { "name": "counter (GDB, from launch.json)", "type": "gdb", "request": "launch",
      "program": "${workspaceFolder}/build/counter", "cwd": "${workspaceFolder}",
      "stopAtBeginningOfMainSubprogram": false }
  ]
}
J

mkrepo nvimlua
cat >"$work/nvimlua/.nvim.lua" <<'L'
-- this project builds with its own command and debugs with GDB
return {
  build = "mkdir -p out && cc -g -O0 -o out/app main.c && touch out/built-by-nvim-lua",
  program = "out/app",
  debug = { name = "app (GDB, from .nvim.lua)", type = "gdb", request = "launch",
            program = "${workspaceFolder}/out/app", cwd = "${workspaceFolder}",
            stopAtBeginningOfMainSubprogram = false },
}
L

run_case() { # name expect_adapter expect_kind [trust]
  local name="$1" adapter="$2" kind="$3" trust="${4:-0}" rep="$work/$1.json"
  NW_TEST_ROOT="$work/$name" NW_TEST_LINE=$bp_line NW_TEST_VAR=frame NW_TEST_OUT="$rep" NW_TEST_TRUST="$trust" \
    timeout 600 nvim --headless -c "luafile $here/editor_test.lua" >/dev/null 2>&1
  local j; j="$(cat "$rep" 2>/dev/null || echo '{}')"
  if python3 - "$rep" "$adapter" "$kind" <<'PY'
import json, sys
r = json.load(open(sys.argv[1])); adapter, kind = sys.argv[2], sys.argv[3]
ok = r.get("PASS") and r.get("adapter") == adapter and r.get("build_kind") == kind \
     and (r.get("compile_commands") or kind == ".nvim.lua") and r.get("clangd_attached") is True
sys.exit(0 if ok else 1)
PY
  then echo "PASS editor: $name ($kind build, $adapter debugger: breakpoint, variable, step, continue)"
  else echo "FAIL editor: $name :: $j"; fails=$((fails+1)); fi
  echo "     $j" | cut -c1-400
}

run_case cmake      lldb CMake
run_case make       lldb Make
run_case launchjson gdb  CMake
run_case nvimlua    gdb  .nvim.lua 1
[ -f "$work/nvimlua/out/built-by-nvim-lua" ] && echo "PASS editor: .nvim.lua build command was used" \
  || { echo "FAIL editor: .nvim.lua build command was used"; fails=$((fails+1)); }
[ -f "$work/make/compile_commands.json" ] && echo "PASS editor: Make project gets compile_commands.json (bear) for clangd" \
  || { echo "FAIL editor: Make project gets compile_commands.json (bear) for clangd"; fails=$((fails+1)); }
exit "$fails"
