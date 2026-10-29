#!/usr/bin/env bash
# Bot parity for levels 1-40, one level per fresh Godot process, so no level can affect
# another through leftover physics state (docs/EXPANSION_PLAN_2.md §1.2).
#   tools/parity.sh check            compare against tools/baseline_1_40*.json
#   tools/parity.sh record           re-record them (only on purpose)
set -u
mode=${1:-check}
fails=0
for spec in "0:baseline_1_40" "0.5:baseline_1_40_e05"; do
  err=${spec%%:*}; file=${spec#*:}
  [ "$mode" = record ] && rm -f "tools/$file.json"
  for L in $(seq 1 40); do
    if [ "$mode" = record ]; then
      godot --headless --fixed-fps 60 -s res://tools/bot.gd -- --levels=$L --error=$err --json=res://tools/$file.json --append >/dev/null 2>&1
    else
      out=$(godot --headless --fixed-fps 60 -s res://tools/bot.gd -- --levels=$L --error=$err --compare=res://tools/$file.json 2>&1)
      if ! echo "$out" | grep -q "REGRESSION GATE: PASS"; then
        echo "$out" | grep -E "REGRESSION|SCRIPT ERROR"
        fails=$((fails + 1))
      fi
    fi
  done
done
if [ "$mode" = record ]; then echo "PARITY: recorded"; exit 0; fi
echo "PARITY: $fails level run(s) differ from the baseline (levels 1-40, error 0 and 0.5)"
[ $fails -eq 0 ]
