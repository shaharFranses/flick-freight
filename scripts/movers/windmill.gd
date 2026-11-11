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
	# tower (tapered)
	var tower = PackedVector2Array([Vector2(hx - 30, Game.ROAD_Y), Vector2(hx + 30, Game.ROAD_Y),
		Vector2(hx + 14, hy + 20), Vector2(hx - 14, hy + 20)])
	var inner = ArtDraw.ink_poly(self, tower, ArtPalette.CREAM, ArtDraw.PROP)
	ArtDraw.clip_rect(self, inner, Rect2(hx + 2, hy, 40, Game.ROAD_Y - hy), ArtPalette.CREAM_SHADE)
	var a0 = _angle(f)
	for i in n:
		var poly = _blade_poly(a0 + TAU * i / n, Vector2(hx, hy))
		ArtDraw.ink_poly(self, poly, ArtPalette.CREAM if i % 2 == 0 else ArtPalette.CORAL, 3.5)
	ArtDraw.ink_circle(self, Vector2(hx, hy), 22, ArtPalette.CHROME, ArtDraw.PROP)
	draw_circle(Vector2(hx, hy), 5, ArtPalette.INK)
