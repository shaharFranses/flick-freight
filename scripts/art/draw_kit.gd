class_name ArtDraw
extends RefCounted
## One line language for everything code-drawn (style guide page 7):
## navy outline INSIDE the shape (the given rect / polygon is the visual edge, so collision
## edges and drawn edges agree), one hard top highlight, one bottom shade, no gradients.
## All sizes are 720p design px.

const INK := ArtPalette.INK
const HERO := 5.5   # truck / vehicle silhouettes, cargo
const PROP := 4.0   # bumpers, posts, obstacles, machines
const SMALL := 2.6  # windows, lights, small marks


## Filled rect with an inside navy outline. radius > 0 rounds the corners.
static func ink_rect(n: CanvasItem, r: Rect2, fill: Color, w := PROP, radius := 0.0):
	if r.size.x <= 0 or r.size.y <= 0:
		return
	if radius > 0.0:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.border_color = INK
		sb.set_border_width_all(int(round(w)))
		sb.set_corner_radius_all(int(round(radius)))
		sb.anti_aliasing = true
		n.draw_style_box(sb, r)
		return
	n.draw_rect(r, INK)
	var inner := r.grow(-w)
	if inner.size.x > 0 and inner.size.y > 0:
		n.draw_rect(inner, fill)


## Filled polygon with an inside navy outline. Returns the inset (fill) polygon.
static func ink_poly(n: CanvasItem, pts: PackedVector2Array, fill: Color, w := PROP) -> PackedVector2Array:
	n.draw_colored_polygon(pts, INK)
	var inner := inset(pts, w)
	if inner.size() >= 3:
		n.draw_colored_polygon(inner, fill)
	return inner


static func inset(pts: PackedVector2Array, w: float) -> PackedVector2Array:
	var res := Geometry2D.offset_polygon(pts, -w)
	if res.is_empty():
		return PackedVector2Array()
	var best: PackedVector2Array = res[0]
	for p in res:
		if p.size() > best.size():
			best = p
	return best


static func ink_circle(n: CanvasItem, c: Vector2, r: float, fill: Color, w := PROP):
	n.draw_circle(c, r, INK)
	if r - w > 0:
		n.draw_circle(c, r - w, fill)


## A bar / strut: navy line with a fill line inside it.
static func ink_line(n: CanvasItem, a: Vector2, b: Vector2, fill: Color, width := 10.0, w := 3.0):
	n.draw_line(a, b, INK, width)
	if width - 2.0 * w > 0:
		var d := (b - a).normalized() * w
		n.draw_line(a + d, b - d, fill, width - 2.0 * w)


## Top highlight band + bottom shade band inside an ink_rect drawn with outline w.
static func bands(n: CanvasItem, r: Rect2, hi: Color, shade: Color, w := PROP, hi_h := 5.0, shade_h := 6.0):
	var inner := r.grow(-w)
	if inner.size.x <= 0 or inner.size.y <= hi_h + shade_h:
		return
	if hi_h > 0:
		n.draw_rect(Rect2(inner.position, Vector2(inner.size.x, hi_h)), hi)
	if shade_h > 0:
		n.draw_rect(Rect2(inner.position.x, inner.end.y - shade_h, inner.size.x, shade_h), shade)


## ink_rect + bands in one call. col = [body, shade, highlight].
static func panel(n: CanvasItem, r: Rect2, col: Array, w := PROP, hi_h := 5.0, shade_h := 6.0):
	ink_rect(n, r, col[0], w)
	bands(n, r, col[2], col[1], w, hi_h, shade_h)


## Wheel in the truck's spec: dark tyre, ring, chrome hub, navy centre. Two bolts so a
## rotating wheel node shows its spin.
static func wheel(n: CanvasItem, c: Vector2, r: float):
	n.draw_circle(c, r, INK)
	n.draw_circle(c, r - 2.5, ArtPalette.TYRE)
	n.draw_arc(c, r * 0.68, 0, TAU, 32, ArtPalette.TYRE_RING, max(2.0, r * 0.085))
	n.draw_circle(c, r * 0.47, INK)
	n.draw_circle(c, r * 0.47 - 2.5, ArtPalette.CHROME)
	for a in [0.0, PI]:
		n.draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.26, max(1.6, r * 0.07), ArtPalette.STEEL)
	n.draw_circle(c, max(2.5, r * 0.13), INK)


static func glass_rect(n: CanvasItem, r: Rect2, w := 3.5):
	ink_rect(n, r, ArtPalette.GLASS, w, 3.0)
	var i := r.grow(-w - 2.0)
	if i.size.x > 8 and i.size.y > 8:
		n.draw_line(i.position + Vector2(i.size.x * 0.3, i.size.y * 0.12), i.position + Vector2(i.size.x * 0.12, i.size.y * 0.8),
			Color.WHITE, 3.0)


static func glass_poly(n: CanvasItem, pts: PackedVector2Array, w := 3.5):
	var inner := ink_poly(n, pts, ArtPalette.GLASS, w)
	if inner.size() >= 3:
		var r := bounds(inner)
		if r.size.x > 10 and r.size.y > 10:
			n.draw_line(r.position + Vector2(r.size.x * 0.3, r.size.y * 0.2), r.position + Vector2(r.size.x * 0.18, r.size.y * 0.75),
				Color.WHITE, 3.0)


static func bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


static func headlight(n: CanvasItem, r: Rect2):
	ink_rect(n, r, ArtPalette.HEADLIGHT, 3.0)


static func chrome(n: CanvasItem, r: Rect2):
	ink_rect(n, r, ArtPalette.CHROME, PROP, 4.0)


## Navy / amber 45-degree hazard band, clipped to the rect, with a navy frame.
static func hazard(n: CanvasItem, hz: Rect2, stripe := 14.0, frame := 3.0):
	n.draw_rect(hz, INK)
	var inner := hz.grow(-frame)
	if inner.size.x <= 0 or inner.size.y <= 0:
		return
	var clip := PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end,
		Vector2(inner.position.x, inner.end.y)])
	var h := inner.size.y
	var x := inner.position.x - h
	while x < inner.end.x:
		var band := PackedVector2Array([Vector2(x, inner.end.y), Vector2(x + stripe, inner.end.y),
			Vector2(x + stripe + h, inner.position.y), Vector2(x + h, inner.position.y)])
		for c in Geometry2D.intersect_polygons(band, clip):
			if c.size() >= 3:
				n.draw_colored_polygon(c, ArtPalette.AMBER)
		x += stripe * 2.0


## Rivet / bolt dot.
static func rivet(n: CanvasItem, c: Vector2, r := 3.0):
	n.draw_circle(c, r + 1.2, ArtPalette.STEEL_SHADE)
	n.draw_circle(c, r, ArtPalette.RIVET)


## Far bed wall behind the cargo, same as the V0 truck's (truck.gd _draw_far_wall_v3):
## steel grey, horizontal seams, stake posts, darker top rail.
static func bed_wall(n: CanvasItem, r: Rect2, posts := 3, rail := true):
	n.draw_rect(r, ArtPalette.BED_WALL)
	for t in [1.0 / 3.0, 2.0 / 3.0]:
		n.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * t - 1, r.size.x, 2), ArtPalette.BED_POST)
	for i in posts:
		var t := float(i + 1) / float(posts + 1)
		n.draw_rect(Rect2(r.position.x + r.size.x * t - 4, r.position.y, 8, r.size.y), ArtPalette.BED_POST)
	if rail:
		n.draw_rect(Rect2(r.position.x, r.position.y - 6, r.size.x, 8), ArtPalette.BED_RAIL)


## Truck-style cab from a cab polygon shaped like every vehicle's "front" part:
## [rear-bottom, rear-top, roof-front, hood-rear, (hood-front,) front-bottom].
## Draws body, roof highlight, bottom shade, a stripe (stripe_col; alpha 0 = none), side window, windshield,
## headlight and front bumper. No face.
static func cab(n: CanvasItem, poly: PackedVector2Array, col: Array, stripe_col := Color.WHITE):
	var x0 := poly[0].x
	var yb := poly[0].y
	var yt := poly[1].y
	var x1 := poly[2].x
	var hood := poly[3]
	var x3 := poly[poly.size() - 1].x
	var inner := ink_poly(n, poly, col[0], HERO)
	if inner.size() < 3:
		return
	# roof highlight, lower shade band (clipped to the inset body)
	clip_rect(n, inner, Rect2(x0, yt + HERO, x3 - x0, 6), col[2])
	clip_rect(n, inner, Rect2(x0, yb - HERO - 12, x3 - x0, 12), col[1])
	if stripe_col.a > 0.0:
		clip_rect(n, inner, Rect2(x0, min(hood.y + 14, yb - 36), x3 - x0, 9), stripe_col)
	# windows
	var top := yt + 12.0
	var bot := hood.y - 3.0
	if bot - top > 14:
		if x1 - x0 > 50:
			glass_rect(n, Rect2(x0 + 12, top, x1 - x0 - 28, bot - top))
		glass_poly(n, PackedVector2Array([Vector2(x1 - 9, top), Vector2(x1 + 3, top),
			Vector2(hood.x - 7, bot), Vector2(x1 - 9, bot)]))
	# headlight + bumper
	headlight(n, Rect2(x3 - 13, hood.y + 10, 13, 13))
	chrome(n, Rect2(x3 - 8, yb - 16, 18, 16))


## Fill the part of rect r that lies inside polygon clip.
static func clip_rect(n: CanvasItem, clip: PackedVector2Array, r: Rect2, c: Color):
	var q := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	for p in Geometry2D.intersect_polygons(q, clip):
		if p.size() >= 3:
			n.draw_colored_polygon(p, c)
