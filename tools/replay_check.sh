#!/usr/bin/env bash
# Deterministic replay (docs/EXPANSION_PLAN_2.md §5.2): each level, played 3 times from a
# fresh start, must give identical results and identical throws (incl. release frames).
#   tools/replay_check.sh 41 100      (levels that don't exist are skipped; runs in parallel)
set -u
from=${1:-41}; to=${2:-200}
count=$(godot --headless -s res://tools/level_count.gd 2>/dev/null | grep -oE '^COUNT [0-9]+' | cut -d' ' -f2)
[ -z "$count" ] && { echo "REPLAY: cannot read level count"; exit 1; }
[ "$to" -gt "$count" ] && to=$count
[ "$from" -gt "$to" ] && { echo "REPLAY CHECK: 0 level(s), 0 not deterministic"; exit 0; }
tmp=$(mktemp -d)
jobs=$(nproc 2>/dev/null || echo 2)
for L in $(seq "$from" "$to"); do for k in 1 2 3; do echo "$L $k"; done; done |
  xargs -P "$jobs" -n 2 sh -c 'godot --headless --fixed-fps 60 -s res://tools/bot.gd -- --levels=$0 --error=0 --json="'"$tmp"'/L$0_r$1.json" >/dev/null 2>&1'
fails=0
for L in $(seq "$from" "$to"); do
  if ! cmp -s "$tmp/L${L}_r1.json" "$tmp/L${L}_r2.json" || ! cmp -s "$tmp/L${L}_r1.json" "$tmp/L${L}_r3.json"; then
    echo "REPLAY: level $L differs between runs"; fails=$((fails + 1))
  fi
done
rm -rf "$tmp"
echo "REPLAY CHECK: $((to - from + 1)) level(s), $fails not deterministic"
[ $fails -eq 0 ]
