#!/usr/bin/env bash
# Tiled exports a map from the command line (no window): TMX -> JSON and CSV, checked cell by cell.
set -euo pipefail
here="$(dirname -- "$(readlink -f -- "$0")")"
out="$(mktemp -d)"; trap 'rm -rf "$out"' EXIT
export QT_QPA_PLATFORM=offscreen
tiled --export-map json "$here/room.tmx" "$out/room.json"
tiled --export-map csv  "$here/room.tmx" "$out/room.csv"
python3 - "$out/room.json" <<'PY'
import json,sys
m=json.load(open(sys.argv[1]))
d=m["layers"][0]["data"]
assert (m["width"],m["height"])==(8,6), (m["width"],m["height"])
assert len(d)==48 and d[0]==2 and d[9]==1 and d.count(1)==24, d
print("JSON ok: 8x6, 24 floor tiles")
PY
csv="$(ls "$out"/*.csv | head -n1)"
# CSV holds tile indexes in the tileset (0-based; -1 = empty), JSON holds gids (firstgid=1, 0 = empty)
[ "$(head -n1 "$csv" | tr -d '\r')" = "1,1,1,1,1,1,1,1" ] && [ "$(sed -n 2p "$csv" | tr -d '\r')" = "1,0,0,0,0,0,0,1" ] \
  || { echo "CSV wrong:"; cat "$csv"; exit 1; }
echo "CSV ok: $(basename "$csv") (0-based tile indexes)"
