#!/usr/bin/env bash
# Phase 2/3 swap-in proof on a scratch copy (the repo itself is never touched):
#   1. full:    a dummy PNG in every Phase 2/3 slot  -> art_fallback_test --p23=present
#   2. partial: every other slot removed again        -> art_fallback_test (per-file)
#   3. none:    all removed                           -> art_fallback_test --p23=empty
# With --parity, also runs tools/parity.sh on the "full" copy (visual drops must not
# change physics: same diffs as the plain tree). With P23_SHOTS=<dir>, also saves the
# tools/art_p23_shots.gd set for the "full" copy (needs xvfb-run).
#   [P23_SHOTS=/tmp/shots] tools/art_p23_dummy.sh [--parity]
#   P23_DUMMY_DIR=/tmp/noart tools/art_p23_dummy.sh --noart   (no Phase 2/3 file at all, for the
#     pixel diff against the pre-Phase-2 tree)
set -eu
src=$(cd "$(dirname "$0")/.." && pwd)
dst=${P23_DUMMY_DIR:-/tmp/ff-p23-dummy}
rm -rf "$dst"; mkdir -p "$dst"
tar -C "$src" --exclude=.git --exclude=export -cf - . | tar -C "$dst" -xf -
cd "$dst"
imp() { godot --headless --import >/dev/null 2>&1 || true; }
# delete a slot completely: the PNG, its .png.import and its .godot/imported cache entries
# (<file>-<md5 of res path>.*), so a stale import cannot keep the art alive
strip() {
  local p=$1 h
  h=$(printf '%s' "res://$p" | md5sum | cut -d' ' -f1)
  rm -f "$p" "$p.import" .godot/imported/"$(basename "$p")-$h".*
}
run() { godot --headless -s res://tools/art_fallback_test.gd -- "$@" 2>&1 | grep -E "^ART|SCRIPT ERROR"; }
if [ "${1:-}" = "--noart" ]; then
  # fallback tree: delete every Phase 2/3 slot (real art included), reimport, check empty
  for p in $(godot --headless -s res://tools/art_fallback_test.gd -- --list_p23 2>/dev/null | sed -n 's/^P23SLOT //p'); do strip "$p"; done
  imp
  run --p23=empty | tee /tmp/p23_noart.out
  grep -q "CHECK: 0 problem" /tmp/p23_noart.out
  echo "ART P23 NOART TREE: $dst"
  exit 0
fi
python3 - <<'PY'
import os
from PIL import Image, ImageDraw
slots = {}
for k, s in {"ice": (58, 58), "tire": (56, 56), "plank": (150, 24), "canister": (44, 58), "parcel": (46, 30)}.items():
    slots[f"art/v3/cargo/{k}.png"] = s
for k in ["box", "crate", "barrel", "fragile", "ice", "tire", "plank", "canister", "parcel"]:
    slots[f"art/v3/cargo/thumb/{k}.png"] = (32, 32)
slots.update({
    "art/v3/ui/star_on.png": (96, 96), "art/v3/ui/star_off.png": (96, 96),
    "art/v3/ui/star_on_s.png": (34, 34), "art/v3/ui/star_off_s.png": (60, 60),
    "art/v3/ui/padlock.png": (96, 96), "art/v3/ui/arrow_right.png": (88, 88), "art/v3/ui/arrow_left.png": (44, 44),
    "art/v3/ui/pause.png": (80, 80), "art/v3/ui/sound_on.png": (80, 80), "art/v3/ui/sound_off.png": (40, 40),
    "art/v3/ui/world/truck.png": (96, 56),
    "art/v3/bg/bg_woods.png": (1280, 720), "art/v3/bg/bg_desert.png": (2560, 1440),
    "art/v3/bg/bg_freight_yard.png": (1280, 720), "art/v3/bg/bg_downtown.png": (1280, 720),
})
for w in ["town", "woods", "desert", "harbor", "snow", "freight_yard", "sky_port", "downtown", "construction"]:
    slots[f"art/v3/ui/world/{w}.png"] = (192, 112)
with open("p23_slots.txt", "w") as f:
    for i, (p, s) in enumerate(sorted(slots.items())):
        os.makedirs(os.path.dirname(p), exist_ok=True)
        im = Image.new("RGBA", s, (40 + (i * 37) % 200, 90, 200 - (i * 23) % 150, 255))
        ImageDraw.Draw(im).rectangle([1, 1, s[0] - 2, s[1] - 2], outline=(27, 42, 65, 255), width=2)
        im.save(p)
        f.write(p + "\n")
PY
fails=0
imp
echo "--- full ($(wc -l < p23_slots.txt) dummy files)"
run --p23=present | tee /tmp/p23_full.out
grep -q "CHECK: 0 problem" /tmp/p23_full.out || fails=$((fails + 1))
if [ -n "${P23_SHOTS:-}" ]; then
  xvfb-run -a -s "-screen 0 1280x720x24" godot --fixed-fps 60 --resolution 1280x720 \
    -s res://tools/art_p23_shots.gd -- --out="$P23_SHOTS" 2>&1 | grep -cE "^shot:" | sed 's/^/shots saved: /'
fi
if [ "${1:-}" = "--parity" ]; then
  echo "--- parity with every dummy present"
  bash tools/parity.sh check 2>&1 | tail -40 || true
fi
echo "--- stale import (padlock.png deleted, its .import and cache left behind)"
rm -f art/v3/ui/padlock.png
run | tee /tmp/p23_stale.out
grep -q "stale import keeps it alive" /tmp/p23_stale.out || { echo "stale import NOT detected"; fails=$((fails + 1)); }
run --clean_stale | grep -E "removed|CHECK"
run | tee /tmp/p23_stale2.out
grep -q "CHECK: 0 problem" /tmp/p23_stale2.out || fails=$((fails + 1))
awk 'NR % 2 == 0' p23_slots.txt | while read -r p; do strip "$p"; done
imp
echo "--- partial (every other slot removed)"
run | tee /tmp/p23_part.out
grep -q "CHECK: 0 problem" /tmp/p23_part.out || fails=$((fails + 1))
while read -r p; do strip "$p"; done < p23_slots.txt
left=0
while read -r p; do
  h=$(printf '%s' "res://$p" | md5sum | cut -d' ' -f1)
  for f in "$p" "$p.import" .godot/imported/"$(basename "$p")-$h".*; do [ -e "$f" ] && left=$((left + 1)); done
done < p23_slots.txt
echo "stale leftovers after strip: $left"; [ $left -eq 0 ] || fails=$((fails + 1))
imp
echo "--- none (all removed)"
run --p23=empty | tee /tmp/p23_none.out
grep -q "CHECK: 0 problem" /tmp/p23_none.out || fails=$((fails + 1))
echo "ART P23 DUMMY: $fails run(s) failed"
[ $fails -eq 0 ]
