#!/usr/bin/env bash
# Release-time search test: a dev gate (tools/test/gate_mover.gd) blocks the throw path for
# half of every 3 s. The bot must time every throw through the gap (3 stars) with no
# ±3 frame jitter failures.
out=$(godot --headless --fixed-fps 60 -s res://tools/bot.gd -- --levels=2 --error=0 --solver=sim --test_mover=res://tools/test/gate_mover.gd 2>&1 | grep "^LEVEL")
echo "$out"
echo "$out" | grep -q "stars=3" && echo "$out" | grep -q "jitter fails 0/" && { echo "TIMING TEST: PASS"; exit 0; }
echo "TIMING TEST: FAIL"; exit 1
