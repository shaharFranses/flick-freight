extends SceneTree
## Layout check: no truck may drive through an obstacle or a bounce pad, anywhere along its
## back-and-forth drive or its drive in from the right.
##   godot --headless -s res://tools/layout_check.gd      (exit 1 if any level overlaps)

const REAR := -157.0  # rear bumper, relative to the bed centre
const FRONT := 319.0  # front bumper
const TOP := -126.0   # top of the cab/bulkhead, relative to the bed floor
const MARGIN := 8.0


func _init():
	var bad = 0
	for i in Levels.count():
		var lv = Levels.get_level(i)
		var trucks: Array = lv.trucks if lv.has("trucks") else [lv.truck]
		var obstacles: Array = []
		for b in lv.get("blocks", []):
			obstacles.append(["block", Rect2(b[0], b[1], b[2], b[3])])
		for p in lv.get("pads", []):
			obstacles.append(["pad", Rect2(p[0] - Game.PAD_W * 0.5, p[1] - 6, Game.PAD_W, Game.PAD_H)])
		var floor_y = Game.ROAD_Y - Truck.FLOOR_T - 18 - Truck.WHEEL_R
		for t in trucks:
			var amp: float = t.get("amp", 0.0)
			var bob: float = t.get("ferry", {}).get("amp_y", 0.0)
			# the area the truck sweeps: its parked drive range, plus driving in from off-screen right
			var drive = Rect2(t.x - amp + REAR, floor_y + TOP - bob, 1700.0, Game.ROAD_Y - floor_y - TOP + bob)
			for o in obstacles:
				var r: Rect2 = o[1]
				if drive.grow(MARGIN).intersects(r):
					var where = "drives through" if r.position.x < t.x + amp + FRONT else "drives in through"
					print("LAYOUT L%d: truck (x %d, amp %d) %s the %s at x %d-%d" % [i + 1, t.x, amp, where, o[0], r.position.x, r.end.x])
					bad += 1
	print("LAYOUT CHECK: %d problem(s)" % bad)
	quit(1 if bad else 0)
