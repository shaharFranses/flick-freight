extends SceneTree
## Regression test: cargo that lands and stays on the driver's cab must be a miss within 1.3s of touching it,
## on a parked truck (level 2) and a moving one (level 3).

var main: Node
var cases = [1, 2]  # level indices
var ci := 0
var t_throw := -1.0
var t := 0.0
var fails := 0
var t_cab := -1.0


func _init():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.PATH))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if ci >= cases.size():
		return true
	var g: Game = main.game
	if g == null:
		return false
	if g.level_index != cases[ci]:
		main.start_level(cases[ci])
		return false
	if t_throw < 0 and g.can_aim():
		# aim the landing at the cab roof
		var target_x = g.truck.position.x + Truck.BED_W * 0.5 + Truck.WALL_T + 50
		var p = _solve(g, target_x, g.truck.position.y - 112)
		g.current.resolved.connect(_on_resolved, CONNECT_ONE_SHOT)
		g.current.body_entered.connect(func(b): if b.is_in_group("truck_cab") and t_cab < 0: t_cab = t)
		g.throw_with_pull(p)
		t_throw = t
	elif t_throw > 0 and t - t_throw > 6.0:
		print("FAIL level %d: no resolve within 6s" % (cases[ci] + 1))
		fails += 1
		_next()
	return false


func _on_resolved(c: Cargo, ok: bool, reason: String):
	var dt = t - t_throw
	# it may stay on the cab or roll off onto the road; either way a quick miss
	var good = (not ok) and t - t_cab < 1.3 and reason in ["cab", "road"]
	print("%s level %d: delivered=%s reason=%s after %.2fs (%.2fs after first touching the cab)" % [
		"PASS" if good else "FAIL", cases[ci] + 1, ok, reason, dt, t - t_cab if t_cab > 0 else -1.0])
	if not good:
		fails += 1
	_next.call_deferred()


func _next():
	ci += 1
	t_throw = -1.0
	t_cab = -1.0
	if ci >= cases.size():
		print("CAB TEST: %d failure(s)" % fails)
		quit(1 if fails else 0)


func _solve(g: Game, tx: float, ty: float) -> Vector2:
	var best = Vector2(100, -100)
	var best_err = INF
	var tr: Truck = g.truck
	for ang in range(15, 80, 1):
		for ln in range(60, int(Game.MAX_PULL) + 1, 2):
			var pull = Vector2(cos(deg_to_rad(ang)), -sin(deg_to_rad(ang))) * ln
			var v = pull * Game.POWER * g.current.power_mult()
			var p = g.current.global_position
			var tt = 0.0
			while tt < 3.0:
				v += Vector2(g.wind, Game.GRAVITY) / 60.0
				p += v / 60.0
				tt += 1.0 / 60.0
				if v.y > 0 and p.y >= ty - 35:
					break
			var x_at = tx
			if tr.amp > 0:
				x_at = tx + tr.amp * sin(TAU * (tr._t + tt) / tr.period) - (tr.position.x - tr.base_x)
			var err = abs(p.x - x_at)
			if err < best_err:
				best_err = err
				best = pull
	return best
