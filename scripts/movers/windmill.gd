extends Mover
## M21: windmill. Blades turn at a constant speed around a hub on a tower; throw through the
## gaps between them. The tower itself is solid too.
## cfg: x, y (hub), blade (length), period (frames per full turn), blades (count), phase

var rotor: AnimatableBody2D
var hx := 640.0
var hy := 300.0
var blade := 150.0
var per := 360
var n := 4
const BW := 26.0  # blade width


func _build():
	hx = cfg.get("x", 640.0)
	hy = cfg.get("y", 300.0)
	blade = cfg.get("blade", 150.0)
	per = int(cfg.get("period", 360))
	n = int(cfg.get("blades", 4))
	var parts: Array = []
	for i in n:
		parts.append(_blade_poly(TAU * i / n, Vector2.ZERO))
	rotor = make_body("block", parts, 0.2, 0.5)
	rotor.position = Vector2(hx, hy)
	# tower: from just under the hub down to the road
	make_body("block", [Rect2(hx - 14, hy + 30, 28, Game.ROAD_Y - hy - 30)])


func period_frames() -> int:
	# blades are symmetric: the picture repeats every 1/n of a turn
	return per / n


func _angle(f: int) -> float:
	return TAU * f / float(per)


func _blade_poly(a: float, c: Vector2) -> PackedVector2Array:
	var d = Vector2(cos(a), sin(a))
	var side = Vector2(-d.y, d.x) * BW * 0.5
	return PackedVector2Array([c + d * 18 + side, c + d * blade + side * 0.7, c + d * blade - side * 0.7, c + d * 18 - side])


func pose_at(f: int):
	rotor.rotation = _angle(f)


func sim_shapes(f: int) -> Array:
	var out: Array = [Rect2(hx - 14, hy + 30, 28, Game.ROAD_Y - hy - 30)]
	var a0 = _angle(f)
	for i in n:
		out.append(_blade_poly(a0 + TAU * i / n, Vector2(hx, hy)))
	return out


func _draw():
	var f = game.frame + phase
	var navy = Color("#1B2A41")
	# tower (tapered)
	draw_colored_polygon(PackedVector2Array([Vector2(hx - 30, Game.ROAD_Y), Vector2(hx + 30, Game.ROAD_Y),
		Vector2(hx + 14, hy + 20), Vector2(hx - 14, hy + 20)]), navy)
	draw_colored_polygon(PackedVector2Array([Vector2(hx - 25, Game.ROAD_Y), Vector2(hx + 25, Game.ROAD_Y),
		Vector2(hx + 10, hy + 24), Vector2(hx - 10, hy + 24)]), Color("#D9C7A3"))
	var a0 = _angle(f)
	for i in n:
		var poly = _blade_poly(a0 + TAU * i / n, Vector2(hx, hy))
		draw_colored_polygon(Geometry2D.offset_polygon(poly, 3)[0], navy)
		draw_colored_polygon(poly, Color("#F4F1EA") if i % 2 == 0 else Color("#E4572E"))
	draw_circle(Vector2(hx, hy), 22, navy)
	draw_circle(Vector2(hx, hy), 17, Color("#AAB4BF"))
