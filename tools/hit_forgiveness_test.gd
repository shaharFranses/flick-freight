extends SceneTree
# r4 design ruling: centre within bay +- 0.25 x drawn width = hit; drawn overlap beyond that = rim (miss + bounce).
const TB = preload("res://scripts/truck_bay.gd")
var passed = 0
var failed = 0

func check(name: String, got, want):
	if got == want:
		passed += 1
		print("PASS ", name, " -> ", got)
	else:
		failed += 1
		print("FAIL ", name, " got ", got, " want ", want)

func _init():
	# forgiveness per type (drawn widths box 81.6, crate 89.6, barrel 78.4)
	check("forgive box", is_equal_approx(TB.forgiveness_px("box"), 20.4), true)
	check("forgive crate", is_equal_approx(TB.forgiveness_px("crate"), 22.4), true)
	check("forgive barrel", is_equal_approx(TB.forgiveness_px("barrel"), 19.6), true)
	check("override", TB.forgiveness_px("box", 10.0), 10.0)
	# QA edge pair (1920x1080: bay 912-1007 px = world 303.4-416.0, scale 0.84375, left 656):
	# tx 1003 -> dx 51.3, tx 1010 -> dx 59.6 : both must be hits
	check("qa tx1003 hit", TB.classify(abs((1003.0 - 656.0) / 0.84375 - 360.0), "box"), "hit")
	check("qa tx1010 hit", TB.classify(abs((1010.0 - 656.0) / 0.84375 - 360.0), "box"), "hit")
	check("inside", TB.classify(0.0, "box"), "hit")
	check("edge of window", TB.classify(55.0 + 20.4, "box"), "hit")
	check("just past window", TB.classify(55.0 + 21.0, "box"), "rim")
	# ~15% of the drawn box overlapping the opening -> rim bounce miss
	check("15% overlap rim", TB.classify(55.0 + 81.6 / 2.0 - 0.15 * 81.6, "box"), "rim")
	check("15% overlap crate rim", TB.classify(55.0 + 89.6 / 2.0 - 0.15 * 89.6, "crate"), "rim")
	check("clear miss", TB.classify(55.0 + 81.6 / 2.0 + 1.0, "box"), "miss")
	check("override 0 strict", TB.classify(56.0, "box", 0.0), "rim")
	print("HIT_FORGIVENESS_TEST passed:%d failed:%d" % [passed, failed])
	quit(0 if failed == 0 else 1)
