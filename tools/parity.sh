#!/usr/bin/env bash
# Bot parity for levels 6-40 (1-5 were unfrozen), one level per fresh Godot process, so no level can affect
# another through leftover physics state (docs/EXPANSION_PLAN_2.md §1.2). Runs in parallel.
#   tools/parity.sh check            compare against tools/baseline_1_40*.json
#   tools/parity.sh record           re-record them (only on purpose)
#
# On a failed check, REGRESSION lines and the PARITY summary are printed first (same as before).
# After the summary, each failed level also prints one line:
#   PARITY_ACTUAL e0 L7 {json}     (or e05), the full actual entry, so a CI job log can update the baseline.
# Pass behaviour and the exit code are unchanged. tools/parity_apply_actual.py reads those lines.
set -u
mode=${1:-check}
jobs=$(nproc 2>/dev/null || echo 2)
tmp=$(mktemp -d)
for spec in "0:baseline_1_40" "0.5:baseline_1_40_e05"; do
  err=${spec%%:*}; file=${spec#*:}
  if [ "$mode" = record ]; then
    rm -f "tools/$file.json"
    # one process per level, then merge (--append) one at a time
    for L in $(seq 6 40); do echo $L; done | xargs -P "$jobs" -I{} sh -c "godot --headless --fixed-fps 60 -s res://tools/bot.gd -- --levels={} --error=$err --json=$tmp/$file.{}.json >/dev/null 2>&1"
    for L in $(seq 6 40); do
      godot --headless -s res://tools/merge_results.gd -- --into=res://tools/$file.json --from=$tmp/$file.$L.json >/dev/null 2>&1
    done
  else
    for L in $(seq 6 40); do echo $L; done | xargs -P "$jobs" -I{} sh -c "godot --headless --fixed-fps 60 -s res://tools/bot.gd -- --levels={} --error=$err --compare=res://tools/$file.json > $tmp/$file.{}.out 2>&1"
  fi
done
if [ "$mode" = record ]; then rm -rf "$tmp"; echo "PARITY: recorded"; exit 0; fi
fails=0
failed_outs=()
for f in "$tmp"/*.out; do
  if ! grep -q "REGRESSION GATE: PASS" "$f"; then
    grep -E "REGRESSION|SCRIPT ERROR" "$f"; fails=$((fails + 1))
    failed_outs+=("$f")
  fi
done
echo "PARITY: $fails level run(s) differ from the baseline (levels 6-40, error 0 and 0.5)"
if [ "$fails" -gt 0 ]; then
  for f in "${failed_outs[@]}"; do
    grep -E "^PARITY_ACTUAL " "$f" || true
  done
fi
rm -rf "$tmp"
[ "$fails" -eq 0 ]
