extends SceneTree
## QA bot. Plays levels by solving throws ballistically (+ optional aim error).
##   godot --headless -s res://tools/bot.gd -- --levels=1-15 --error=0.0
## Prints per-level results; exits non-zero if a level can't be passed by a perfect thrower.
## Also used windowed with --write-movie for screenshots/video.

var main: Node
var levels: Array = []
var li := 0
var error := 0.0
var results: Array = []
var wait := 0.0
var level_time := 0.0
var shots := 0
var stop_after := -1.0
var t_total := 0.0
var stay := false


func _init():
	var args = {}
	for a in OS.get_cmdline_user_args():
		var p = a.trim_prefix("--").split("=")
		args[p[0]] = p[1] if p.size() > 1 else "1"
	var r = args.get("levels", "1-15").split("-")
	for i in range(int(r[0]), int(r[r.size() - 1]) + 1):
		levels.append(i - 1)
	error = float(args.get("error", "0"))
	stop_after = float(args.get("seconds", "-1"))
	stay = args.has("stay")
	seed(int(args.get("seed", "3")))
	if args.get("fresh", "1") == "1":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.PATH))
	Game.verbose = args.has("verbose")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t_total += delta
	if stop_after > 0 and t_total > stop_after:
		quit(0)
		return true
	if main.game == null:
		return false
	if main.level_index != levels[li]:
		main.start_level(levels[li])
		level_time = 0.0
		shots = 0
		return false
	level_time += delta
	var g: Game = main.game
	if g.ended:
		wait += delta
		if wait > 2.0:
			wait = 0.0
			var stars = SaveData.stars(g.level_index)
			results.append([g.level_index + 1, g.delivered, g.level.cargo.length(), Levels.stars_for(g.level_index, g.delivered), int(level_time)])
			print("LEVEL %d: loaded %d/%d  stars=%d  time=%ds" % results[-1])
			if stay:
				return false
			li += 1
			if li >= levels.size():
				_report()
				return true
			main.start_level(levels[li])
			level_time = 0.0
		return false
	if g.can_aim():
		wait += delta
		if wait > 0.35:
			wait = 0.0
			var p = solve(g)
			if error > 0:
				p = p.rotated(randf_range(-error, error) * 0.12) * (1.0 + randf_range(-error, error) * 0.1)
			g.throw_with_pull(p)
			shots += 1
	return false


func _report():
	var fails = 0
	for r in results:
		if r[3] == 0:
			fails += 1
	print("BOT DONE: %d levels, %d failed" % [results.size(), fails])
	quit(1 if fails > 0 and error == 0.0 else 0)


## Search pull vectors, simulate the arc, and pick the one whose landing point
## is closest to the bed centre at the moment of landing.
func solve(g: Game) -> Vector2:
	var t: Truck = g.truck
	var p0 = g.current.global_position
	var target_y = t.global_position.y - 30.0 - 20.0 * t.load_count()
	var best = Vector2(100, -100)
	var best_err = INF
	var blocks: Array = []
	for b in g.level.get("blocks", []):
		blocks.append(Rect2(b[0], b[1], b[2], b[3]).grow(26))
	var mult = g.current.power_mult()
	var wall_top = t.global_position.y - t.wall_h
	for ang in range(10, 80, 2):
		for ln in range(60, int(Game.MAX_PULL) + 1, 3):
			var pull = Vector2(cos(deg_to_rad(ang)), -sin(deg_to_rad(ang))) * ln
			var v = pull * Game.POWER * mult
			var p = p0
			var tt = 0.0
			var ok = true
			var landed = false
			var prev = p
			while tt < 3.0:
				v += Vector2(g.wind, Game.GRAVITY) / 60.0
				prev = p
				p += v / 60.0
				tt += 1.0 / 60.0
				for r in blocks:
					if r.has_point(p):
						ok = false
				if not ok:
					break
				if v.y > 0 and p.y >= target_y:
					landed = true
					break
			if not ok or not landed:
				continue
			# where will the truck be?
			var tx = t.base_x
			if t.amp > 0:
				tx = t.base_x + t.amp * sin(TAU * (t._t + tt) / t.period)
			var err = abs(p.x - tx)
			# must clear the tailgate on the way in
			var at_gate_x = tx - Truck.BED_W * 0.5 - Truck.WALL_T
			if prev.x < at_gate_x and p.y > wall_top - 30:
				err += 200
			# prefer steeper (softer) landings slightly, and penalize very fast ones
			err += v.length() * 0.01
			if err < best_err:
				best_err = err
				best = pull
	return best
