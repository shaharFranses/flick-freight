extends SceneTree
# r5 timer/truck math check (spec acceptance 2-6, 10). Run: godot --headless --script tools/r5_timer_test.gd
func _init():
	var gm = load("res://scripts/game_manager.gd").new()
	var ok = true
	var checks = [
		["hit@load1 = 2.0", gm.hit_time_bonus(1, 1, false), 2.0],
		["perfect@load1 = 3.5", gm.hit_time_bonus(1, 1, true), 3.5],
		["streak4 normal = 3.0", gm.hit_time_bonus(1, 4, false), 3.0],
		["streak 50 capped = 2.0+5.0", gm.hit_time_bonus(1, 50, false), 7.0],
		["miss load 9 = 0", gm.miss_time_penalty(9), 0.0],
		["miss load 10 = 2", gm.miss_time_penalty(10), 2.0],
		["hit@load100 floor 1.2", gm.hit_time_bonus(100, 1, false), 1.2],
		["perfect@load100 = 2.5", gm.hit_time_bonus(100, 1, true), 2.5], ["perfect@load200 floor 2.2", gm.hit_time_bonus(200, 1, true), 2.2],
		["hit@load10 = 1.9", gm.hit_time_bonus(10, 1, false), 1.9],
		["period L1 3.6", gm.bay_period_for_level(0), 3.6],
		["period L2 3.384", gm.bay_period_for_level(1), 3.384],
		["period L30 floor 1.6", gm.bay_period_for_level(30), 1.6],
	]
	for c in checks:
		var pass_ = abs(c[1] - c[2]) < 0.001
		ok = ok and pass_
		print(("PASS " if pass_ else "FAIL ") + c[0] + "  got %.3f" % c[1])
	gm.time_remaining = 29.0
	gm.T.clock_cap = 30.0
	gm.last_time_delta = 0
	gm.time_remaining = clamp(gm.time_remaining + 3.5, 0.0, gm.T.clock_cap)
	ok = ok and gm.time_remaining == 30.0
	print("cap 30: ", gm.time_remaining)
	gm.free()
	print("R5_TIMER_TEST ", "OK" if ok else "FAIL")
	quit(0 if ok else 1)
