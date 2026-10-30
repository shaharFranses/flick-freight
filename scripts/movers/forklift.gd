extends Mover
## M22: forklift patrolling back and forth along the floor with its forks raised. It shoves
## cargo that's on the ground or low on its arc (bank shots off a pad, flat throws).
## cfg: x0, x1 (patrol range of its centre), period, forks (fork height above the road), phase
##      lift (optional, px): the forks carry a pallet of crates and raise it this much higher,
##      up into the throw arc, once every lift_period frames

var body_r: AnimatableBody2D  # facing right
var body_l: AnimatableBody2D  # facing left (physics bodies can't be mirrored by scale)
var x0 := 420.0
var x1 := 760.0
var per := 300
var forks := 90.0
var lift := 0.0
var lift_per := 300
var car_r: AnimatableBody2D  # fork carriage + pallet, only when lifting
var car_l: AnimatableBody2D

const LOAD_H := 64.0


func _build():
	x0 = cfg.get("x0", 420.0)
	x1 = cfg.get("x1", 760.0)
	per = int(cfg.get("period", 300))
	forks = cfg.get("forks", 90.0)
	lift = cfg.get("lift", 0.0)
	lift_per = int(cfg.get("lift_period", per))
	body_r = make_body("block", _parts(1.0), 0.2, 0.6)
	body_l = make_body("block", _parts(-1.0), 0.2, 0.6)
	if lift > 0:
		car_r = make_body("block", _car(1.0), 0.2, 0.6)
		car_l = make_body("block", _car(-1.0), 0.2, 0.6)


func period_frames() -> int:
	return Game._lcm(per, lift_per) if lift > 0 else per


## How far the carriage is raised above its rest height at frame f.
func _raise(f: int) -> float:
	return lift * (0.5 - 0.5 * cos(TAU * f / float(lift_per))) if lift > 0 else 0.0


func _cx(f: int) -> float:
	return (x0 + x1) * 0.5 + (x1 - x0) * 0.5 * sine(f, per)


## Facing: forks point the way it's driving.
func _dir(f: int) -> float:
	return 1.0 if cos(TAU * f / float(per)) >= 0.0 else -1.0


## Solid parts relative to (centre, road): chassis + cab block, mast, forks.
func _parts(d: float) -> Array:
	var y0 = Game.ROAD_Y
	var parts = [
		PackedVector2Array([Vector2(-55, y0 - 10), Vector2(55, y0 - 10), Vector2(55, y0 - 52), Vector2(-55, y0 - 52)]),
		PackedVector2Array([Vector2(-50 * d, y0 - 52), Vector2(-10 * d, y0 - 52), Vector2(-10 * d, y0 - 120), Vector2(-50 * d, y0 - 120)]),
		PackedVector2Array([Vector2(55 * d, y0 - 10), Vector2(65 * d, y0 - 10), Vector2(65 * d, y0 - forks - 40), Vector2(55 * d, y0 - forks - 40)]),
	]
	if lift <= 0:
		parts.append(PackedVector2Array([Vector2(65 * d, y0 - forks), Vector2(125 * d, y0 - forks), Vector2(125 * d, y0 - forks - 8), Vector2(65 * d, y0 - forks - 8)]))
	for i in parts.size():  # keep winding consistent when mirrored
		if d < 0:
			parts[i].reverse()
	return parts


## The lifting carriage at rest height (it moves up by _raise): inner mast, forks, and a
## pallet with two crates on them.
func _car(d: float) -> Array:
	var y0 = Game.ROAD_Y
	var fy = y0 - forks
	var parts = [
		PackedVector2Array([Vector2(55 * d, fy + lift), Vector2(65 * d, fy + lift), Vector2(65 * d, fy - 50), Vector2(55 * d, fy - 50)]),
		PackedVector2Array([Vector2(65 * d, fy), Vector2(125 * d, fy), Vector2(125 * d, fy - LOAD_H), Vector2(65 * d, fy - LOAD_H)]),
	]
	for i in parts.size():
		if d < 0:
			parts[i].reverse()
	return parts


func pose_at(f: int):
	var right = _dir(f) > 0
	body_r.position = Vector2(_cx(f), 0)
	body_l.position = Vector2(_cx(f), 0)
	body_r.collision_layer = 1 if right else 0
	body_l.collision_layer = 0 if right else 1
	if lift > 0:
		car_r.position = Vector2(_cx(f), -_raise(f))
		car_l.position = Vector2(_cx(f), -_raise(f))
		car_r.collision_layer = 1 if right else 0
		car_l.collision_layer = 0 if right else 1


func sim_shapes(f: int) -> Array:
	var out: Array = []
	var cx = _cx(f)
	for poly in _parts(_dir(f)):
		var moved = PackedVector2Array()
		for p in poly:
			moved.append(p + Vector2(cx, 0))
		out.append(moved)
	if lift > 0:
		var off = Vector2(cx, -_raise(f))
		for poly in _car(_dir(f)):
			var moved = PackedVector2Array()
			for p in poly:
				moved.append(p + off)
			out.append(moved)
	return out


func _draw():
	var f = game.frame + phase
	var navy = Color("#1B2A41")
	var cx = _cx(f)
	var d = _dir(f)
	var y0 = Game.ROAD_Y
	var yellow = Color("#F2B134")
	draw_rect(Rect2(cx - 58, y0 - 55, 116, 48), navy)
	draw_rect(Rect2(cx - 55, y0 - 52, 110, 42), yellow)
	# cab cage
	draw_line(Vector2(cx - 50 * d, y0 - 52), Vector2(cx - 50 * d, y0 - 120), navy, 5.0)
	draw_line(Vector2(cx - 10 * d, y0 - 52), Vector2(cx - 10 * d, y0 - 120), navy, 5.0)
	draw_line(Vector2(cx - 54 * d, y0 - 120), Vector2(cx - 6 * d, y0 - 120), navy, 7.0)
	# mast + forks
	draw_rect(Rect2(min(cx + 55 * d, cx + 65 * d), y0 - forks - 40, 10, forks + 30), navy)
	var r = _raise(f)
	if lift > 0:
		# inner mast slides up out of the outer one, carrying the pallet
		var fy = y0 - forks - r
		draw_rect(Rect2(min(cx + 56 * d, cx + 64 * d), fy - 50, 8, r + 20), Color("#3A4658"))
		draw_line(Vector2(cx + 60 * d, fy - 50), Vector2(cx + 60 * d, y0 - forks - 40), Color("#C9CED6"), 2.0)
		var lx = min(cx + 65 * d, cx + 125 * d)
		draw_rect(Rect2(lx, fy - 8, 60, 8), Color("#5B6574"))
		draw_rect(Rect2(lx + 2, fy - 16, 56, 8), Color("#8A5A32"))  # pallet
		for k in 2:
			var cr = Rect2(lx + 5, fy - 16 - 24 * (k + 1), 50, 24)
			draw_rect(cr.grow(2), navy)
			draw_rect(cr, Color("#C98E4A"))
			draw_line(cr.position + Vector2(0, 12), cr.position + Vector2(50, 12), Color("#A26B33"), 2.0)
	else:
		draw_rect(Rect2(min(cx + 65 * d, cx + 125 * d), y0 - forks - 8, 60, 8), Color("#5B6574"))
	# wheels + beacon
	for wx in [cx - 34, cx + 34]:
		draw_circle(Vector2(wx, y0 - 10), 14, Color("#2E3440"))
		draw_circle(Vector2(wx, y0 - 10), 6, Color("#C9CED6"))
	if (f / 10) % 2 == 0:
		draw_circle(Vector2(cx - 30 * d, y0 - 128), 6, Color("#FF9F1C"))
