extends SceneTree
## QA bot. Plays levels by solving throws (+ optional aim error).
##   godot --headless --fixed-fps 60 -s res://tools/bot.gd -- --levels=1-15 --error=0.0
## Prints per-level results; exits non-zero if a level can't be passed by a perfect thrower.
## Also used windowed with --write-movie for screenshots/video.
##
## Options:
##   --levels=A-B|all      level range (1-based)
##   --error=E             aim error (0 = perfect, 0.5 = human-like)
##   --seed=N              base seed; each level gets its own RNG seeded from (N, level)
##   --solver=auto|analytic|sim
##                         auto = analytic for the frozen levels 1-15, sim for everything after
##   --json=res://...      write per-level results as JSON
##   --compare=res://...   fail (exit 1) if any level in that JSON gives a different result
##   --snap=path.png --snap_at=S   save a screenshot after S seconds (needs a display, e.g. xvfb-run)
##   --seconds=S, --stay, --verbose, --fresh=0

const FROZEN_LEVELS := 15

var main: Node
var levels: Array = []
var li := 0
var error := 0.0
var base_seed := 3
var solver := "auto"
var json_out := ""
var compare_path := ""
var rng := RandomNumberGenerator.new()
var results: Array = []
var wait := 0.0
var level_time := 0.0
var shots := 0
var stop_after := -1.0
var t_total := 0.0
var stay := false
var snap := ""
var snap_at := 0.0
var _game_id := 0
var _broken := 0
var _candidates := 0
var _good := 0


func _init():
	var args = {}
	for a in OS.get_cmdline_user_args():
		var p = a.trim_prefix("--").split("=")
		args[p[0]] = p[1] if p.size() > 1 else "1"
	var r = args.get("levels", "1-15").replace("all", "1-%d" % Levels.count()).split("-")
	for i in range(int(r[0]), int(r[r.size() - 1]) + 1):
		levels.append(i - 1)
	error = float(args.get("error", "0"))
	stop_after = float(args.get("seconds", "-1"))
	stay = args.has("stay")
	snap = args.get("snap", "")
	snap_at = float(args.get("snap_at", "3"))
	base_seed = int(args.get("seed", "3"))
	solver = args.get("solver", "auto")
	json_out = args.get("json", "")
	compare_path = args.get("compare", "")
	seed(base_seed)
	if args.get("fresh", "1") == "1":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.PATH))
	Game.verbose = args.has("verbose")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t_total += delta
	if snap != "" and t_total >= snap_at:
		root.get_texture().get_image().save_png(snap)
		print("snap: %s" % snap)
		snap = ""
	if stop_after > 0 and t_total > stop_after:
		quit(0)
		return true
	if main.game == null:
		return false
	if main.level_index != levels[li]:
		main.start_level(levels[li])
		return false
	var g: Game = main.game
	if g.get_instance_id() != _game_id:
		_begin_level(g)
	level_time += delta
	if g.ended:
		wait += delta
		if wait > 2.0:
			wait = 0.0
			_record(g)
			if stay:
				return false
			li += 1
			if li >= levels.size():
				_report()
				return true
			main.start_level(levels[li])
		return false
	if g.can_aim():
		wait += delta
		if wait > 0.35:
			wait = 0.0
			var p = solve(g) if _use_analytic(g) else solve_sim(g)
			if error > 0:
				p = p.rotated(rng.randf_range(-error, error) * 0.12) * (1.0 + rng.randf_range(-error, error) * 0.1)
			g.throw_with_pull(p)
			shots += 1
	return false


## Every level gets its own RNG so results don't depend on which levels ran before
## (or on random numbers the game itself draws for effects).
func _begin_level(g: Game):
	_game_id = g.get_instance_id()
	rng.seed = hash([base_seed, g.level_index])
	level_time = 0.0
	shots = 0
	wait = 0.0
	_broken = 0
	_candidates = 0
	_good = 0
	g.cargo_resolved.connect(func(_kind, _ok, reason):
		if reason == "broken":
			_broken += 1)


func _use_analytic(g: Game) -> bool:
	if solver == "analytic":
		return true
	if solver == "sim":
		return false
	return g.level_index < FROZEN_LEVELS


func _record(g: Game):
	var total: int = Levels.cargo_list(g.level_index).size()
	var stars = Levels.stars_for(g.level_index, g.delivered)
	var r = {"level": g.level_index + 1, "pass": stars > 0, "stars": stars, "delivered": g.delivered,
		"missed": total - g.delivered - _broken, "broken": _broken, "total": total}
	results.append(r)
	var extra = ""
	if _candidates > 0:
		# share of candidate throws (over the whole level) that would have landed in a truck
		extra = "  sim: %d cands, %.1f%% good" % [_candidates, 100.0 * _good / _candidates]
	print("LEVEL %d: loaded %d/%d  stars=%d  broken=%d  time=%ds%s" % [r.level, r.delivered, total, stars, _broken, int(level_time), extra])
	if _candidates > 0 and stars == 3 and float(_good) / _candidates < 0.02:
		print("  WARNING: level %d needs very precise throws (<2%% of candidates land)" % r.level)


func _report():
	var fails = 0
	for r in results:
		if not r.pass:
			fails += 1
	print("BOT DONE: %d levels, %d failed" % [results.size(), fails])
	if json_out != "":
		var f = FileAccess.open(json_out, FileAccess.WRITE)
		f.store_string(JSON.stringify({"error": error, "seed": base_seed, "levels": results}, "  ") + "\n")
		f.close()
		print("wrote %s" % json_out)
	var regress = _compare() if compare_path != "" else 0
	quit(1 if (fails > 0 and error == 0.0) or regress > 0 else 0)


func _compare() -> int:
	var data = JSON.parse_string(FileAccess.get_file_as_string(compare_path))
	if data == null:
		print("REGRESSION: cannot read %s" % compare_path)
		return 1
	var mine = {}
	for r in results:
		mine[int(r.level)] = r
	var diffs = 0
	for b in data.levels:
		var lv = int(b.level)
		if not mine.has(lv):
			continue
		for k in ["pass", "stars", "delivered", "missed", "broken", "total"]:
			if str(mine[lv][k]) != str(b[k] if typeof(b[k]) != TYPE_FLOAT else int(b[k])):
				print("REGRESSION: level %d %s = %s, baseline %s" % [lv, k, mine[lv][k], b[k]])
				diffs += 1
	print("REGRESSION GATE: %s (%d differences vs %s)" % ["PASS" if diffs == 0 else "FAIL", diffs, compare_path])
	return diffs


## Analytic solver, kept unchanged for levels 1-15 so the regression baseline stays identical.
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
			var spots = [-70.0, 30.0, -20.0, 75.0, -90.0, 0.0]
			var err = abs(p.x - (tx + spots[t.load_count() % spots.size()]))
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


# ======================================================================= simulation solver
## Search solver for levels 16+. Samples a grid of (angle, power), steps each throw
## frame by frame through a model of the level (wind, obstacles, truck motion and
## walls; later mechanics plug in via BotSim) and scores where it ends up.
func solve_sim(g: Game) -> Vector2:
	var sim = BotSim.new(g)
	var best = Vector2(100, -100)
	var best_score = INF
	for ang in range(-40, 84, 2):
		for ln in range(40, int(Game.MAX_PULL) + 1, 3):
			var pull = Vector2(cos(deg_to_rad(ang)), -sin(deg_to_rad(ang))) * ln
			var s = sim.score(pull)
			_candidates += 1
			if sim.last_dist < BotSim.GOOD:
				_good += 1
			if s < best_score:
				best_score = s
				best = pull
	return best
