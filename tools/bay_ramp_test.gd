extends SceneTree
# r5 bay test (replaces the r3 ramp test). Design ruling: no ramp by default; the truck
# holds centre until the run's first flick resolves, then runs a 3.6 s sine of +-180 px.
# Ramp only with ?qa=1&ramp=1 (ramp_enabled). Run: godot --headless --script tools/bay_ramp_test.gd
var bay; var results = []
func ok(name, cond, info = ""):
	results.append(cond); print(("PASS " if cond else "FAIL ") + name + (" " + info if info != "" else ""))
func frames(n, dt := 1.0 / 60.0):
	for i in n: bay._process(dt)
func _init():
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame; await process_frame
	bay = m.get_node("World/TruckBay")
	bay.set_process(false)  # drive _process by hand, deterministic dt
	bay.reset_position()
	frames(300)
	ok("holds centre before first flick (5 s)", is_equal_approx(bay.position.x, 360.0), str(bay.position.x))
	ok("ramp off by default", bay.ramp_enabled == false)
	bay.release_hold(); bay.set_period(3.6)
	var mn = 1e9; var mx = -1e9
	for i in 216:  # one 3.6 s period
		bay._process(1.0 / 60.0); mn = min(mn, bay.position.x); mx = max(mx, bay.position.x)
	ok("travel +-180 after release", abs(mn - 180.0) < 1.0 and abs(mx - 540.0) < 1.0, "%.1f..%.1f" % [mn, mx])
	frames(1)
	ok("one period returns near centre", abs(bay.position.x - 360.0) < 20.0, "%.1f" % bay.position.x)
	bay.reset_position(); frames(60)
	ok("reset_position re-holds centre", is_equal_approx(bay.position.x, 360.0))
	bay.release_hold(); bay.set_speed_multiplier(0.25); frames(54)  # 0.9 s at 0.25x = quarter of 3.6s/4
	var expect = 360.0 + sin(0.9 * 0.25 / 3.6 * TAU) * 180.0
	ok("qa 0.25x speed", abs(bay.position.x - expect) < 1.0, "%.1f vs %.1f" % [bay.position.x, expect])
	bay.set_speed_multiplier(1.0); bay.ramp_enabled = true; bay.reset_position(); bay.release_hold()
	frames(6)  # 0.1 s at ramp ~0.6
	var exp2 = 360.0 + sin(0.1 * 0.6 / 3.6 * TAU) * 180.0
	ok("ramp (qa toggle) starts ~0.6x", abs(bay.position.x - exp2) < 1.5, "%.1f vs %.1f" % [bay.position.x, exp2])
	var all_ok = not results.has(false)
	print("PASSED:%d FAILED:%d" % [results.count(true), results.count(false)])
	quit(0 if all_ok else 1)
