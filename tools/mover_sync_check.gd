extends SceneTree
## Every moving obstacle's solid bodies must really move with the level clock (not only its
## drawing): reports bodies that stay put over two seconds.
##   godot --headless --fixed-fps 60 -s res://tools/mover_sync_check.gd

var main
var li := 0
var levels: Array = []
var start := {}
var frames := 0
var problems := 0


func _initialize():
	for i in Levels.count():
		if Levels.get_level(i).has("movers"):
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
		frames = 0
		return false
	frames += 1
	var g = main.game
	if frames == 5:
		for m in g.movers:
			for b in _bodies(m):
				start[b] = b.global_transform
	elif frames == 71:
		for m in g.movers:
			if m.period_frames() == 0:
				continue
			var moved = false
			for b in _bodies(m):
				if not start.has(b) or not b.global_transform.is_equal_approx(start[b]):
					moved = true
			if not moved and not _bodies(m).is_empty():
				problems += 1
				print("  level %d: %s bodies never moved" % [levels[li] + 1, m.cfg.type])
		li += 1
	return false


func _bodies(m: Node) -> Array:
	var out: Array = []
	for c in m.get_children():
		if c is AnimatableBody2D:
			out.append(c)
	return out
