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
	var navy = ArtPalette.INK
	var amber = [ArtPalette.AMBER, ArtPalette.AMBER_SHADE, ArtPalette.AMBER_HI]
	var jib_l = min(mast_x - 140, px - abs(slide) - 60)
	var jib_r = max(mast_x + 60, px + abs(slide) + 80)
	# mast: lattice tower down to the ground. It is scenery (nothing collides with it),
	# so it uses the pastel background language: light fill, thin tinted ink.
	var mast = Rect2(mast_x - 16, py, 32, Game.ROAD_Y - py)
	draw_rect(mast, ArtPalette.BG_INK)
	draw_rect(mast.grow_individual(-3, 0, -3, 0), ArtPalette.PLANK_HI)
	var y = py
	while y < Game.ROAD_Y - 24:
		draw_line(Vector2(mast_x - 13, y), Vector2(mast_x + 13, y + 24), ArtPalette.BG_INK, 2.0)
		draw_line(Vector2(mast_x + 13, y), Vector2(mast_x - 13, y + 24), ArtPalette.BG_INK, 2.0)
		y += 24.0
	# tie bars, jib, counterweight, cab
	draw_line(Vector2(mast_x, py - 16), Vector2(mast_x, py - 60), navy, 4.0)
	draw_line(Vector2(mast_x, py - 60), Vector2(jib_r, py - 16), navy, 2.5)
	draw_line(Vector2(mast_x, py - 60), Vector2(jib_l, py - 16), navy, 2.5)
	var jib = Rect2(jib_l - 3, py - 19, jib_r - jib_l + 6, 22)
	ArtDraw.ink_rect(self, jib, ArtPalette.AMBER, 3.0)
	var k = jib_l
	while k < jib_r - 20:
		draw_line(Vector2(k, py - 15), Vector2(k + 20, py - 1), navy, 2.0)
		k += 20.0
	ArtDraw.ink_rect(self, Rect2(jib_l - 3, py - 4, 76, 38), ArtPalette.STEEL, 3.0)  # counterweight
	draw_rect(Rect2(jib_l, py - 1, 70, 5), ArtPalette.STEEL_LIGHT)
	ArtDraw.panel(self, Rect2(mast_x - 24, py - 2, 48, 38), amber, 3.0, 4.0, 5.0)
	ArtDraw.glass_rect(self, Rect2(mast_x - 15, py + 7, 30, 17), 2.6)
	# trolley, cable, beam
	var p = _pivot(f)
	ArtDraw.ink_rect(self, Rect2(p.x - 18, py - 4, 36, 13), ArtPalette.STEEL, 3.0)
	var t = _box_xf(f)
	var top = t * Vector2(0, -load_size.y * 0.5)
	draw_line(p + Vector2(0, 8), top, navy, 3.0)
	var h = load_size * 0.5
	var poly = PackedVector2Array([t * Vector2(-h.x, -h.y), t * Vector2(h.x, -h.y), t * Vector2(h.x, h.y), t * Vector2(-h.x, h.y)])
	ArtDraw.ink_poly(self, poly, ArtPalette.CORAL, 3.5)
	draw_line(t * Vector2(-h.x + 5, 0), t * Vector2(h.x - 5, 0), ArtPalette.CORAL_SHADE, 5.0)  # I-beam web
