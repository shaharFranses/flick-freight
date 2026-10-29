#!/usr/bin/env bash
# Deterministic replay (docs/EXPANSION_PLAN_2.md §5.2): each level, played 3 times from a
# fresh start, must give identical results and identical throws (incl. release frames).
#   tools/replay_check.sh 41 100      (levels that don't exist are skipped)
set -u
from=${1:-41}; to=${2:-200}
count=$(godot --headless -s res://tools/level_count.gd 2>/dev/null | grep -oE '^COUNT [0-9]+' | cut -d' ' -f2)
[ -z "$count" ] && { echo "REPLAY: cannot read level count"; exit 1; }
[ "$to" -gt "$count" ] && to=$count
tmp=$(mktemp -d)
fails=0; n=0
for L in $(seq "$from" "$to"); do
  n=$((n + 1))
  for k in 1 2 3; do
    godot --headless --fixed-fps 60 -s res://tools/bot.gd -- --levels=$L --error=0 --json="$tmp/r$k.json" >/dev/null 2>&1
  done
  if ! cmp -s "$tmp/r1.json" "$tmp/r2.json" || ! cmp -s "$tmp/r1.json" "$tmp/r3.json"; then
    echo "REPLAY: level $L differs between runs"; fails=$((fails + 1))
  fi
done
rm -rf "$tmp"
echo "REPLAY CHECK: $n level(s), $fails not deterministic"
[ $fails -eq 0 ]
