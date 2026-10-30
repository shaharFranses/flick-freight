#!/usr/bin/env bash
# Performance smoke test: native headless physics time on the heaviest levels.
#   tools/perf_check.sh 25 38 40 49       (bot level IDs, 1-based)
# - a retired level (bot prints "no levels to play (retired)") is a warning, not a failure
# - any other level without a LEVEL line fails
# - a level whose max physics time per frame is above MAX_MS fails, after one re-run (a single
#   slow frame on a shared CI runner shouldn't fail the build; a real regression repeats)
set -u
MAX_MS=${MAX_MS:-12}
fails=0
run() {
  timeout 600 godot --headless --fixed-fps 60 -s res://tools/bot.gd -- --levels=$1 --error=0 --perf 2>&1
}
for L in "$@"; do
  out=$(run $L)
  if grep -q "no levels to play (retired)" <<<"$out"; then
    echo "::warning title=perf::level $L is retired, skipped"
    continue
  fi
  line=$(grep "^LEVEL" <<<"$out")
  if [ -z "$line" ]; then
    echo "::error title=perf::level $L printed no LEVEL line"
    grep -E "SCRIPT ERROR|ERROR" <<<"$out" | head -5
    fails=$((fails + 1))
    continue
  fi
  echo "$line"
  max=$(sed -n 's/.*physics: avg [0-9.]* ms, max \([0-9.]*\) ms per frame.*/\1/p' <<<"$line")
  if [ -z "$max" ]; then
    echo "::error title=perf::level $L: no physics timing in the LEVEL line"
    fails=$((fails + 1))
  elif awk -v m="$max" -v lim="$MAX_MS" 'BEGIN { exit !(m > lim) }'; then
    echo "level $L: max $max ms > $MAX_MS ms, re-running once"
    line=$(run $L | grep "^LEVEL")
    echo "$line"
    max=$(sed -n 's/.*physics: avg [0-9.]* ms, max \([0-9.]*\) ms per frame.*/\1/p' <<<"$line")
    if [ -z "$max" ] || awk -v m="$max" -v lim="$MAX_MS" 'BEGIN { exit !(m > lim) }'; then
      echo "::error title=perf::level $L: max physics ${max:-?} ms per frame > $MAX_MS ms (twice)"
      fails=$((fails + 1))
    fi
  fi
done
echo "PERF: $fails failure(s)"
[ $fails -eq 0 ]
