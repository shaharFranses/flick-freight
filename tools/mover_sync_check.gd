extends SceneTree
## Every moving obstacle's solid bodies, and those of vehicles that move on the level clock
## (helicopter, balloon), must really move (not only their drawing): reports bodies that stay
## put over a second.
##   godot --headless --fixed-fps 60 -s res://tools/mover_sync_check.gd

var main
var li := 0
var levels: Array = []
var start := {}
var moved := {}
var frames := 0
var problems := 0


func _initialize():
	for i in Levels.count():
		if Levels.get_level(i).has("movers") or _clock_vehicle(Levels.get_level(i)):
			levels.append(i)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	if main.game == null:
		return false
	if li >= levels.size():
		print("MOVER SYNC: %d problem(s)" % problems)
		quit(1 if problems > 0 else 0)
		return true
	if main.level_index != levels[li]:
		main.start_level(levels[li])
		start = {}
		moved = {}
		frames = 0
		return false
	frames += 1
	var g = main.game
	if frames == 110:  # vehicles have arrived by now
		for m in _moving(g):
			for b in _bodies(m):
				start[b] = b.global_transform
	elif frames == 150 or frames == 191:  # two samples, so a symmetric swing can't fool it
		for m in _moving(g):
			for b in _bodies(m):
				if start.has(b) and not b.global_transform.is_equal_approx(start[b]):
					moved[m] = true
		if frames == 191:
			for m in _moving(g):
				if m.period_frames() > 0 and not _bodies(m).is_empty() and not moved.has(m):
					problems += 1
					print("  level %d: %s bodies never moved" % [levels[li] + 1, m.cfg.type if m is Mover else m.get_script().resource_path.get_file()])
			li += 1
	return false


static func _clock_vehicle(lv: Dictionary) -> bool:
	for t in (lv.trucks if lv.has("trucks") else [lv.truck]):
		if t.get("vehicle", "") in ["heli", "balloon"]:
			return true
	return false


func _moving(g) -> Array:
	return g.movers + g.live_trucks().filter(func(t): return t.period_frames() > 0)


func _bodies(m: Node) -> Array:
	var out: Array = []
	for c in m.get_children():
		if c is AnimatableBody2D:
			out.append(c)
	return out
