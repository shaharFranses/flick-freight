#!/usr/bin/env bash
# Bot parity for levels 1-40, one level per fresh Godot process, so no level can affect
# another through leftover physics state (docs/EXPANSION_PLAN_2.md §1.2). Runs in parallel.
#   tools/parity.sh check            compare against tools/baseline_1_40*.json
#   tools/parity.sh record           re-record them (only on purpose)
set -u
mode=${1:-check}
jobs=$(nproc 2>/dev/null || echo 2)
tmp=$(mktemp -d)
for spec in "0:baseline_1_40" "0.5:baseline_1_40_e05"; do
  err=${spec%%:*}; file=${spec#*:}
  if [ "$mode" = record ]; then
    rm -f "tools/$file.json"
    # one process per level, then merge (--append) one at a time
    for L in $(seq 1 40); do echo $L; done | xargs -P "$jobs" -I{} sh -c "godot --headless --fixed-fps 60 -s res://tools/bot.gd -- --levels={} --error=$err --json=$tmp/$file.{}.json >/dev/null 2>&1"
    for L in $(seq 1 40); do
      godot --headless -s res://tools/merge_results.gd -- --into=res://tools/$file.json --from=$tmp/$file.$L.json >/dev/null 2>&1
    done
  else
    for L in $(seq 1 40); do echo $L; done | xargs -P "$jobs" -I{} sh -c "godot --headless --fixed-fps 60 -s res://tools/bot.gd -- --levels={} --error=$err --compare=res://tools/$file.json > $tmp/$file.{}.out 2>&1"
  fi
done
if [ "$mode" = record ]; then rm -rf "$tmp"; echo "PARITY: recorded"; exit 0; fi
fails=0
for f in "$tmp"/*.out; do
  if ! grep -q "REGRESSION GATE: PASS" "$f"; then
    grep -E "REGRESSION|SCRIPT ERROR" "$f"; fails=$((fails + 1))
  fi
done
rm -rf "$tmp"
echo "PARITY: $fails level run(s) differ from the baseline (levels 1-40, error 0 and 0.5)"
[ $fails -eq 0 ]
