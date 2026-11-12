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
	# trolley: a little carriage riding the jib on two wheels
	var p = _pivot(f)
	ArtDraw.ink_rect(self, Rect2(p.x - 20, py - 4, 40, 15), ArtPalette.STEEL, 3.0)
	draw_rect(Rect2(p.x - 17, py - 1, 34, 3), ArtPalette.STEEL_LIGHT)
	ArtDraw.ink_circle(self, Vector2(p.x - 11, py - 4), 4.0, ArtPalette.STEEL_SHADE, 2.0)
	ArtDraw.ink_circle(self, Vector2(p.x + 11, py - 4), 4.0, ArtPalette.STEEL_SHADE, 2.0)
	# hoist: twin cables down to a hook block, two slings from the hook to the beam's ends
	var t = _box_xf(f)
	var h = load_size * 0.5
	var a = _angle(f)
	var down = Vector2(sin(a), cos(a))
	var side = Vector2(cos(a), -sin(a))
	var hook = p + down * max(_cable(f) - 34.0, 14.0)
	draw_line(p + Vector2(-4, 10), hook - side * 4, navy, 2.5)
	draw_line(p + Vector2(4, 10), hook + side * 4, navy, 2.5)
	var blk = PackedVector2Array([hook - side * 11 - down * 4, hook + side * 11 - down * 4,
		hook + side * 9 + down * 12, hook - side * 9 + down * 12])
	ArtDraw.ink_poly(self, blk, ArtPalette.AMBER, 2.5)
	ArtDraw.ink_circle(self, hook + down * 3, 3.5, ArtPalette.STEEL_LIGHT, 2.0)
	var eye = hook + down * 20
	draw_arc(eye + down * 2, 5.0, 0.0, TAU, 12, navy, 3.0)
	var sl = t * Vector2(-h.x + 26, -h.y)
	var sr = t * Vector2(h.x - 26, -h.y)
	draw_line(eye, sl, navy, 2.5)
	draw_line(eye, sr, navy, 2.5)
	ArtDraw.ink_circle(self, sl, 3.0, ArtPalette.STEEL, 1.5)
	ArtDraw.ink_circle(self, sr, 3.0, ArtPalette.STEEL, 1.5)
	# the beam: an I-beam seen from the side. Flanges top and bottom, a darker web with
	# lightening holes between them, rivets along the flanges.
	var q = func(x0, y0, x1, y1): return PackedVector2Array([t * Vector2(x0, y0), t * Vector2(x1, y0), t * Vector2(x1, y1), t * Vector2(x0, y1)])
	draw_colored_polygon(q.call(-h.x, -h.y, h.x, h.y), ArtPalette.CORAL_SHADE)  # web
	var fl = 7.0
	draw_colored_polygon(q.call(-h.x, -h.y, h.x, -h.y + fl), ArtPalette.CORAL)
	draw_colored_polygon(q.call(-h.x, h.y - fl, h.x, h.y), ArtPalette.CORAL)
	draw_colored_polygon(q.call(-h.x + 3, -h.y + 1.5, h.x - 3, -h.y + 3.5), ArtPalette.CORAL_HI)
	draw_line(t * Vector2(-h.x, -h.y + fl), t * Vector2(h.x, -h.y + fl), navy, 1.5)
	draw_line(t * Vector2(-h.x, h.y - fl), t * Vector2(h.x, h.y - fl), navy, 1.5)
	var x = -h.x + 30.0
	while x < h.x - 20:
		draw_circle(t * Vector2(x, 0), 4.0, navy)
		x += 28.0
	x = -h.x + 9.0
	while x < h.x - 4:
		draw_circle(t * Vector2(x, -h.y + fl * 0.5), 1.6, ArtPalette.CORAL_SHADE)
		draw_circle(t * Vector2(x, h.y - fl * 0.5), 1.6, ArtPalette.CORAL_SHADE)
		x += 16.0
	var outline = q.call(-h.x, -h.y, h.x, h.y)
	outline.append(outline[0])
	draw_polyline(outline, navy, 3.5)
