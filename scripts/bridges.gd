class_name Bridges
extends RefCounted
## Low bridges for the height limit (M14 / Plan 2 D2), drawn in code per world.
## `deck` is the bridge deck: its bottom edge is the clearance. Everything is drawn from
## there to the right edge of the screen and up, so it sits over the parked truck's cab.

const NAVY = Color("#1B2A41")


static func draw(n: Node2D, style: String, deck: Rect2, road_y: float):
	match style:
		"rock", "snow_rock":
			_rock(n, deck, style == "snow_rock")
		"steel":
			_steel(n, deck, road_y)
		"wood":
			_wood(n, deck, road_y)
		_:
			_stone(n, deck, road_y)
	_sign(n, Vector2(deck.position.x + 46, deck.end.y - 30))


## Yellow "max height" sign on the deck face: arrows pointing at the clearance.
static func _sign(n: Node2D, c: Vector2):
	var d = PackedVector2Array([c + Vector2(0, -24), c + Vector2(24, 0), c + Vector2(0, 24), c + Vector2(-24, 0)])
	n.draw_colored_polygon(d, NAVY)
	var inner = PackedVector2Array([c + Vector2(0, -19), c + Vector2(19, 0), c + Vector2(0, 19), c + Vector2(-19, 0)])
	n.draw_colored_polygon(inner, Color("#FFD34E"))
	n.draw_line(c + Vector2(0, -11), c + Vector2(0, 11), NAVY, 3.0)
	for s in [-1.0, 1.0]:
		n.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 13 * s), c + Vector2(-6, 6 * s), c + Vector2(6, 6 * s)]), NAVY)


static func _rock(n: Node2D, deck: Rect2, snow: bool):
	var x0 = deck.position.x
	var y = deck.end.y
	# overhanging cliff: jagged underside at the clearance, mass rising to the top right
	var pts = PackedVector2Array([Vector2(x0 - 10, y - 30), Vector2(x0 + 4, y - 6), Vector2(x0 + 40, y),
		Vector2(deck.end.x, y), Vector2(deck.end.x, -300), Vector2(x0 + 160, -300),
		Vector2(x0 + 120, y - 140), Vector2(x0 + 50, y - 100), Vector2(x0 + 10, y - 70)])
	n.draw_colored_polygon(_grow(pts, 3), NAVY)
	n.draw_colored_polygon(pts, Color("#7D8B9C"))
	n.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 30, y - 4), Vector2(deck.end.x, y - 4),
		Vector2(deck.end.x, y - 26), Vector2(x0 + 60, y - 30)]), Color("#64717F"))
	for k in 5:
		var cx = x0 + 70 + k * 46
		n.draw_line(Vector2(cx, y - 60 - (k % 2) * 30), Vector2(cx + 20, y - 40 - (k % 3) * 18), Color("#64717F"), 4.0)
	if snow:
		var cap = PackedVector2Array([Vector2(x0 - 12, y - 32), Vector2(x0 + 10, y - 74), Vector2(x0 + 52, y - 104),
			Vector2(x0 + 122, y - 146), Vector2(x0 + 140, y - 128), Vector2(x0 + 60, y - 84), Vector2(x0 + 18, y - 54)])
		n.draw_colored_polygon(cap, Color("#F4FAFF"))
		for k in 6:  # short drips, inside the clearance line
			var ix = x0 + 30 + k * 34
			n.draw_colored_polygon(PackedVector2Array([Vector2(ix - 5, y - 2), Vector2(ix + 5, y - 2), Vector2(ix, y + 6)]), Color("#BFE7F7"))


static func _steel(n: Node2D, deck: Rect2, road_y: float):
	var d = deck
	# pier at the right edge
	var pier = Rect2(max(d.position.x + 150, 1236), d.end.y, 48, road_y - d.end.y)
	n.draw_rect(pier.grow(3), NAVY)
	n.draw_rect(pier, Color("#6B7A8F"))
	n.draw_rect(Rect2(pier.position.x + 8, pier.position.y, 8, pier.size.y), Color("#7F8EA3"))
	# railing
	for x in range(int(d.position.x) + 8, int(d.end.x), 26):
		n.draw_line(Vector2(x, d.position.y), Vector2(x, d.position.y - 22), NAVY, 4.0)
	n.draw_line(Vector2(d.position.x, d.position.y - 22), Vector2(d.end.x, d.position.y - 22), NAVY, 5.0)
	# girder deck with rivets and a hazard stripe along the underside
	n.draw_rect(d.grow(3), NAVY)
	n.draw_rect(d, Color("#3E4A5C"))
	n.draw_rect(d.grow(-6), Color("#6B7A8F"))
	for x in range(int(d.position.x) + 14, int(d.end.x), 30):
		n.draw_circle(Vector2(x, d.position.y + 12), 3, NAVY)
		n.draw_circle(Vector2(x, d.end.y - 20), 3, NAVY)
	_hazard(n, Rect2(d.position.x, d.end.y - 10, d.size.x, 10))


static func _wood(n: Node2D, deck: Rect2, road_y: float):
	var d = deck
	var post = Rect2(max(d.position.x + 150, 1236), d.end.y, 36, road_y - d.end.y)
	n.draw_rect(post.grow(3), NAVY)
	n.draw_rect(post, Color("#8A5A32"))
	n.draw_rect(d.grow(3), NAVY)
	n.draw_rect(d, Color("#A87444"))
	for k in 4:
		n.draw_line(Vector2(d.position.x, d.position.y + 14 + k * 14), Vector2(d.end.x, d.position.y + 14 + k * 14), Color("#7A4E2A"), 3.0)
	for x in range(int(d.position.x) + 30, int(d.end.x), 60):
		n.draw_line(Vector2(x, d.position.y), Vector2(x + 30, d.end.y), Color("#7A4E2A"), 5.0)


static func _stone(n: Node2D, deck: Rect2, road_y: float):
	var d = deck
	var pier = Rect2(max(d.position.x + 150, 1230), d.end.y, 56, road_y - d.end.y)
	n.draw_rect(pier.grow(3), NAVY)
	n.draw_rect(pier, Color("#A9A08F"))
	n.draw_rect(d.grow(3), NAVY)
	n.draw_rect(d, Color("#B8AE9A"))
	for row in 3:
		var y = d.position.y + row * 21
		var off = 0 if row % 2 == 0 else 22
		for x in range(int(d.position.x) + off, int(d.end.x), 44):
			n.draw_rect(Rect2(x + 2, y + 2, 40, 17), Color("#C9C0AC"))
	_hazard(n, Rect2(d.position.x, d.end.y - 9, d.size.x, 9))


static func _hazard(n: Node2D, hz: Rect2):
	n.draw_rect(hz, Color("#2E3440"))
	var sx = hz.position.x - hz.size.y
	while sx < hz.end.x:
		var poly = PackedVector2Array([Vector2(sx, hz.end.y), Vector2(sx + hz.size.y, hz.position.y),
			Vector2(sx + hz.size.y + 10, hz.position.y), Vector2(sx + 10, hz.end.y)])
		var clip = Geometry2D.intersect_polygons(poly, PackedVector2Array([hz.position,
			Vector2(hz.end.x, hz.position.y), hz.end, Vector2(hz.position.x, hz.end.y)]))
		for c in clip:
			n.draw_colored_polygon(c, Color("#F2B134"))
		sx += 20.0


static func _grow(pts: PackedVector2Array, by: float) -> PackedVector2Array:
	var out = Geometry2D.offset_polygon(pts, by)
	return out[0] if out.size() > 0 else pts
