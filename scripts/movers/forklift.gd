extends Mover
## M22: forklift patrolling back and forth along the floor with its forks raised. It shoves
## cargo that's on the ground or low on its arc (bank shots off a pad, flat throws).
## cfg: x0, x1 (patrol range of its centre), period, forks (fork height above the road), phase

var body_r: AnimatableBody2D  # facing right
var body_l: AnimatableBody2D  # facing left (physics bodies can't be mirrored by scale)
var x0 := 420.0
var x1 := 760.0
var per := 300
var forks := 90.0


func _build():
	x0 = cfg.get("x0", 420.0)
	x1 = cfg.get("x1", 760.0)
	per = int(cfg.get("period", 300))
	forks = cfg.get("forks", 90.0)
	body_r = make_body("block", _parts(1.0), 0.2, 0.6)
	body_l = make_body("block", _parts(-1.0), 0.2, 0.6)


func period_frames() -> int:
	return per


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
		PackedVector2Array([Vector2(65 * d, y0 - forks), Vector2(125 * d, y0 - forks), Vector2(125 * d, y0 - forks - 8), Vector2(65 * d, y0 - forks - 8)]),
	]
	for i in parts.size():  # keep winding consistent when mirrored
		if d < 0:
			parts[i].reverse()
	return parts


func pose_at(f: int):
	var right = _dir(f) > 0
	body_r.position = Vector2(_cx(f), 0)
	body_l.position = Vector2(_cx(f), 0)
	body_r.collision_layer = 1 if right else 0
	body_l.collision_layer = 0 if right else 1


func sim_shapes(f: int) -> Array:
	var out: Array = []
	var cx = _cx(f)
	for poly in _parts(_dir(f)):
		var moved = PackedVector2Array()
		for p in poly:
			moved.append(p + Vector2(cx, 0))
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
	draw_rect(Rect2(min(cx + 65 * d, cx + 125 * d), y0 - forks - 8, 60, 8), Color("#5B6574"))
	# wheels + beacon
	for wx in [cx - 34, cx + 34]:
		draw_circle(Vector2(wx, y0 - 10), 14, Color("#2E3440"))
		draw_circle(Vector2(wx, y0 - 10), 6, Color("#C9CED6"))
	if (f / 10) % 2 == 0:
		draw_circle(Vector2(cx - 30 * d, y0 - 128), 6, Color("#FF9F1C"))
