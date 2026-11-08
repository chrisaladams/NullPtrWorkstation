#!/usr/bin/env bash
# Game Boy C source-level debugging test (Emulicious Debug Adapter).
# Run on the installed workstation, inside the graphical session:
#   tests/dap/gameboy-dap-test.sh            [project, default ~/Projects/gameboy-hello]
# Builds the Debug ROM, starts `emulicious -remotedebug 58870` (the same adapter nvim-dap
# uses), then via raw DAP: breakpoint on the C line `keys = joypad();`, wait for the stop,
# check the stopped source line, read variables, step, continue.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="${1:-$HOME/Projects/gameboy-hello}"
target="$(sed -n 's/^target=//p' "$root/.nullptr-project")"
gb-build "$root"
line="$(grep -n 'keys = joypad();' "$root/src/main.c" | cut -d: -f1)"
port=58870
i3-msg -q 'workspace number "6: game"' 2>/dev/null || true
emulicious -remotedebug "$port" >/tmp/emulicious-dap.log 2>&1 &
emu=$!
trap 'kill $emu 2>/dev/null || true' EXIT
python3 -I "$here/dap_client.py" --tcp "127.0.0.1:$port" --timeout 60 \
  --program "$root/build/debug/$target.gb" --source "$root/src/main.c" --line "$line" --var keys \
  --launch-extra "{\"additionalSrcFolders\": \"$root/src\", \"port\": $port}"
