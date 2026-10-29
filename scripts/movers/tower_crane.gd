extends "res://scripts/movers/crane.gd"
## Tower crane (Construction, an M16 variant): a steel beam hangs from a trolley that runs
## along the jib, so the load slides sideways as well as swinging.
## cfg: as the crane; x is the trolley's middle, y the jib, slide its travel. mast_x: where
##      the tower stands (default: left of the trolley's range).

var mast_x := 0.0


func _build():
	load_size = Vector2(170, 26)
	super._build()
	mast_x = cfg.get("mast_x", px - abs(slide) - 120)


func _draw():
	var f = game.frame + phase
	var navy = Color("#1B2A41")
	var yellow = Color("#F2B134")
	var jib_l = min(mast_x - 140, px - abs(slide) - 60)
	var jib_r = max(mast_x + 60, px + abs(slide) + 80)
	# mast: lattice tower down to the ground (behind everything, so drawn faintly)
	var mast = Rect2(mast_x - 16, py, 32, Game.ROAD_Y - py)
	draw_rect(mast, Color(0.95, 0.69, 0.2, 0.55))
	var y = py
	while y < Game.ROAD_Y - 24:
		draw_line(Vector2(mast_x - 16, y), Vector2(mast_x + 16, y + 24), Color(0.106, 0.165, 0.255, 0.35), 2.0)
		draw_line(Vector2(mast_x + 16, y), Vector2(mast_x - 16, y + 24), Color(0.106, 0.165, 0.255, 0.35), 2.0)
		y += 24.0
	# cab + counterweight + jib
	draw_rect(Rect2(jib_l, py - 16, jib_r - jib_l, 16).grow(3), navy)
	draw_rect(Rect2(jib_l, py - 16, jib_r - jib_l, 16), yellow)
	var k = jib_l
	while k < jib_r - 20:
		draw_line(Vector2(k, py - 16), Vector2(k + 20, py), navy, 2.0)
		k += 20.0
	draw_rect(Rect2(jib_l, py - 2, 70, 34), Color("#6B7A8F"))  # counterweight
	draw_rect(Rect2(mast_x - 22, py, 44, 34).grow(2), navy)
	draw_rect(Rect2(mast_x - 22, py, 44, 34), yellow)
	draw_rect(Rect2(mast_x - 14, py + 6, 28, 16), Color("#BFE7F7"))
	draw_line(Vector2(mast_x, py - 16), Vector2(mast_x, py - 60), navy, 4.0)
	draw_line(Vector2(mast_x, py - 60), Vector2(jib_r, py - 16), navy, 2.0)
	draw_line(Vector2(mast_x, py - 60), Vector2(jib_l, py - 16), navy, 2.0)
	# trolley, cable, beam
	var p = _pivot(f)
	draw_rect(Rect2(p.x - 18, py - 4, 36, 12), navy)
	var t = _box_xf(f)
	var top = t * Vector2(0, -load_size.y * 0.5)
	draw_line(p + Vector2(0, 8), top, navy, 3.0)
	var h = load_size * 0.5
	var poly = PackedVector2Array([t * Vector2(-h.x, -h.y), t * Vector2(h.x, -h.y), t * Vector2(h.x, h.y), t * Vector2(-h.x, h.y)])
	draw_colored_polygon(Geometry2D.offset_polygon(poly, 3)[0], navy)
	draw_colored_polygon(poly, Color("#C0392B"))
	draw_line(t * Vector2(-h.x, 0), t * Vector2(h.x, 0), Color("#8E2A20"), 6.0)  # I-beam web
