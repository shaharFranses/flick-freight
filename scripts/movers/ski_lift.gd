extends Mover
## M19: ski lift. Chairs ride a cable from A (dock side) to B (above the vehicle). At B a
## chair tips forward and drops whatever it carries, then returns along an upper cable.
## Land cargo on a chair to ride it in, or bank a throw off a chair's backrest.
## cfg: ax, ay, bx, by (cable ends), chairs (count), speed (px/s along the cable), phase

var chairs: Array = []  # AnimatableBody2D per chair
var a := Vector2(380, 230)
var b := Vector2(900, 330)
var n := 3
var speed := 110.0
const DROP := 64.0  # hanger length, cable to seat
const SEAT := Vector2(78, 10)
const BACK_H := 36.0
const TIP := 70.0  # px of travel over which the chair tips at B
const RETURN_UP := 70.0  # the return cable runs this much higher


func _build():
	a = Vector2(cfg.get("ax", 380.0), cfg.get("ay", 230.0))
	b = Vector2(cfg.get("bx", 900.0), cfg.get("by", 330.0))
	n = int(cfg.get("chairs", 3))
	speed = cfg.get("speed", 110.0)
	for i in n:
		# seat plate + backrest (behind the direction of travel, i.e. on the A side)
		chairs.append(make_body("block", [Rect2(-SEAT.x * 0.5, 0, SEAT.x, SEAT.y),
			Rect2(-SEAT.x * 0.5, -BACK_H, 8, BACK_H)], 0.25, 0.9))


func _seg() -> float:
	return a.distance_to(b)


func _loop() -> float:
	return 2.0 * _seg() + 2.0 * RETURN_UP


func period_frames() -> int:
	# chairs are evenly spaced: the picture repeats when each moves to the next one's place
	return int(round(_loop() / n / speed * 60.0))


## Travelled distance of chair i at frame f.
func _s(i: int, f: int) -> float:
	return fposmod(f * speed / 60.0 + i * _loop() / n, _loop())


## Cable point and seat tilt for a travelled distance s.
func _pose(s: float) -> Array:
	var L = _seg()
	var dir = (b - a) / L
	if s < L:
		var tilt = 0.0
		if s > L - TIP:
			tilt = deg_to_rad(75.0) * (s - (L - TIP)) / TIP  # tips forward at B
		return [a + dir * s, tilt]
	s -= L
	if s < RETURN_UP:
		return [b - Vector2(0, s), deg_to_rad(75.0) * (1.0 - s / RETURN_UP)]
	s -= RETURN_UP
	if s < L:
		return [b - Vector2(0, RETURN_UP) - dir * s, 0.0]
	s -= L
	return [a - Vector2(0, RETURN_UP - s), 0.0]


func _chair_xf(i: int, f: int) -> Transform2D:
	var pt = _pose(_s(i, f))
	return Transform2D(pt[1], pt[0] + Vector2(0, DROP))


func pose_at(f: int):
	for i in n:
		var t = _chair_xf(i, f)
		chairs[i].position = t.origin
		chairs[i].rotation = t.get_rotation()


func sim_shapes(f: int) -> Array:
	var out: Array = []
	for i in n:
		var t = _chair_xf(i, f)
		for r in [Rect2(-SEAT.x * 0.5, 0, SEAT.x, SEAT.y), Rect2(-SEAT.x * 0.5, -BACK_H, 8, BACK_H)]:
			out.append(PackedVector2Array([t * r.position, t * Vector2(r.end.x, r.position.y), t * r.end, t * Vector2(r.position.x, r.end.y)]))
	return out


## Bot: cargo falling onto a level seat on the way to B rides it to B and is tipped off there.
func sim_catch(p: Vector2, v: Vector2, hh: float, f: int) -> Dictionary:
	if v.y <= 0:
		return {}
	var L = _seg()
	for i in n:
		var s = _s(i, f)
		if s > L - TIP - 10:
			continue
		var seat = _chair_xf(i, f).origin
		if abs(p.x - seat.x) < SEAT.x * 0.5 - 6 and p.y + hh >= seat.y - 2 and p.y + hh <= seat.y + 12:
			var frames = int((L - s) / speed * 60.0) + 8
			var drop = _pose(L)[0] + Vector2(SEAT.x * 0.3, DROP - hh)
			var dir = (b - a) / L
			return {"p": drop, "v": dir * speed + Vector2(40, 0), "frames": frames}
	return {}


func _draw():
	var f = game.frame + phase
	var navy = Color("#1B2A41")
	# towers + cables
	for end in [a, b]:
		draw_rect(Rect2(end.x - 8, end.y - RETURN_UP - 20, 16, Game.ROAD_Y - end.y + RETURN_UP + 20), Color(0.106, 0.165, 0.255, 0.5))
		draw_rect(Rect2(end.x - 22, end.y - RETURN_UP - 26, 44, RETURN_UP + 34), Color(0.106, 0.165, 0.255, 0.7))
	draw_line(a, b, navy, 3.0)
	draw_line(a - Vector2(0, RETURN_UP), b - Vector2(0, RETURN_UP), navy, 3.0)
	for i in n:
		var pt = _pose(_s(i, f))
		var t = _chair_xf(i, f)
		draw_line(pt[0], t.origin, navy, 4.0)
		var seat = PackedVector2Array([t * Vector2(-SEAT.x * 0.5, 0), t * Vector2(SEAT.x * 0.5, 0), t * Vector2(SEAT.x * 0.5, SEAT.y), t * Vector2(-SEAT.x * 0.5, SEAT.y)])
		var back = PackedVector2Array([t * Vector2(-SEAT.x * 0.5, -BACK_H), t * Vector2(-SEAT.x * 0.5 + 8, -BACK_H), t * Vector2(-SEAT.x * 0.5 + 8, 0), t * Vector2(-SEAT.x * 0.5, 0)])
		for poly in [seat, back]:
			draw_colored_polygon(Geometry2D.offset_polygon(poly, 2)[0], navy)
			draw_colored_polygon(poly, Color("#E4572E"))
