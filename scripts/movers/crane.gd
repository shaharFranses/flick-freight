extends Mover
## M16: harbor gantry crane. A container hangs from a cable and swings like a pendulum across
## the throw path; the trolley can also slide along the gantry. The cable creaks at the top
## of each swing.
## cfg: x (trolley centre), y (gantry beam), length (cable), swing (deg), period,
##      slide (trolley travel, px), slide_period, phase

const BOX := Vector2(140, 64)
var load_size := BOX  # what hangs on the hook (the tower crane hangs a steel beam)

var box: AnimatableBody2D
var px := 640.0
var py := 50.0
var cable := 260.0
var swing := 30.0
var per := 200
var slide := 0.0
var slide_per := 400


func _build():
	px = cfg.get("x", 640.0)
	py = cfg.get("y", 50.0)
	cable = cfg.get("length", 260.0)
	swing = deg_to_rad(cfg.get("swing", 30.0))
	per = int(cfg.get("period", 200))
	slide = cfg.get("slide", 0.0)
	slide_per = int(cfg.get("slide_period", per * 2))
	box = make_body("block", [Rect2(-load_size * 0.5, load_size)], 0.15)


func period_frames() -> int:
	return per if slide == 0.0 else Game._lcm(per, slide_per)


func _pivot(f: int) -> Vector2:
	return Vector2(px + slide * sine(f, slide_per), py)


func _angle(f: int) -> float:
	return swing * sine(f, per)


func _box_xf(f: int) -> Transform2D:
	var a = _angle(f)
	var c = _pivot(f) + Vector2(sin(a), cos(a)) * (cable + load_size.y * 0.5)
	return Transform2D(-a, c)


func pose_at(f: int):
	var t = _box_xf(f)
	box.position = t.origin
	box.rotation = t.get_rotation()
	# creak at the top of each swing (the tell)
	if posmod(f, per) == per / 4 or posmod(f, per) == 3 * per / 4:
		if game.frame > 0:
			Sfx.play("rim", -14.0, 0.45)


func sim_shapes(f: int) -> Array:
	var t = _box_xf(f)
	var h = load_size * 0.5
	return [PackedVector2Array([t * Vector2(-h.x, -h.y), t * Vector2(h.x, -h.y), t * Vector2(h.x, h.y), t * Vector2(-h.x, h.y)])]


func _draw():
	var f = game.frame + phase
	var navy = Color("#1B2A41")
	var steel = Color("#E8955E")
	# gantry beam + trolley
	draw_rect(Rect2(px - abs(slide) - 260, py - 22, 520 + 2 * abs(slide), 22).grow(3), navy)
	draw_rect(Rect2(px - abs(slide) - 260, py - 22, 520 + 2 * abs(slide), 22), steel)
	var p = _pivot(f)
	draw_rect(Rect2(p.x - 24, py - 6, 48, 18), navy)
	# cable + container
	var t = _box_xf(f)
	var top = t * Vector2(0, -load_size.y * 0.5)
	draw_line(p + Vector2(0, 12), top, navy, 4.0)
	var h = load_size * 0.5
	var poly = PackedVector2Array([t * Vector2(-h.x, -h.y), t * Vector2(h.x, -h.y), t * Vector2(h.x, h.y), t * Vector2(-h.x, h.y)])
	draw_colored_polygon(Geometry2D.offset_polygon(poly, 3)[0], navy)
	draw_colored_polygon(poly, Color("#C9826B"))
	for k in 5:
		var a = t * Vector2(-h.x + 16 + k * 27, -h.y + 8)
		var b = t * Vector2(-h.x + 16 + k * 27, h.y - 8)
		draw_line(a, b, Color("#A8644F"), 4.0)
