#!/usr/bin/env bash
# raylib/GDB source-level debugging test, two layers:
#  1. raw DAP against `gdb --interpreter=dap`           (adapter works)
#  2. nvim-dap with the workstation's AstroNvim config  (editor integration works)
# Run on the installed workstation inside the graphical session. Needs GDB >= 16 (Debian 13).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="${1:-$HOME/Projects/raylib-hello}"
line="$(grep -n 'frameCount++;' "$root/src/main.c" | cut -d: -f1)"
build "$root"
i3-msg -q 'workspace number "6: game"' 2>/dev/null || true   # games must be visible to start
echo "== raw DAP (gdb $(gdb --version | head -1 | awk '{print $NF}'))"
python3 -I "$here/dap_client.py" --stdio "gdb --quiet --interpreter=dap" \
  --program "$root/build/debug/$(sed -n 's/^target=//p' "$root/.nullptr-project")" \
  --source "$root/src/main.c" --line "$line" --var frameCount
echo "== nvim-dap"
NW_TEST_ROOT="$root" NW_TEST_LINE="$line" NW_TEST_VAR=frameCount NW_TEST_OUT=/tmp/nvim-dap-raylib.json \
  nvim --headless -c "luafile $here/nvim_dap_test.lua" || true
python3 -c 'import json;d=json.load(open("/tmp/nvim-dap-raylib.json"));d.pop("console",None);print(json.dumps(d,indent=1));raise SystemExit(0 if d.get("PASS") else 1)'
i3-msg -q 'workspace number "1: astro"' 2>/dev/null || true
