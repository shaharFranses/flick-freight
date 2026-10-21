class_name Art
extends RefCounted
# r4 art direction (flick-freight-audit/art-direction.md): flat vector, 4px navy outline
# (baked as Line2D, no shader -> cheap on phones), 7-colour palette.

const NAVY = Color("#1B2A41")
const FIELD = Color("#DCE8F2")
const CORAL = Color("#E4572E")
const AMBER = Color("#F2B134")
const BLUE = Color("#3D8BDB")
const BROWN = Color("#6B4226")
const MINT = Color("#3DDC97")
const WHITE = Color(1, 1, 1)
const OUTLINE_W = 4.0

const TEX_SPARK = preload("res://art/kenney/spark_05.png")
const TEX_STAR = preload("res://art/kenney/star_06.png")
const TEX_SMOKE = preload("res://art/kenney/smoke_04.png")
const TEX_FLAME = preload("res://art/kenney/flame_03.png")
const TEX_RING = preload("res://art/kenney/circle_05.png")

static func rrect(x: float, y: float, w: float, h: float, r: float, seg := 4) -> PackedVector2Array:
	var p = PackedVector2Array()
	r = min(r, min(w, h) * 0.5)
	var cs = [Vector2(x + w - r, y + r), Vector2(x + w - r, y + h - r), Vector2(x + r, y + h - r), Vector2(x + r, y + r)]
	var a0 = [-PI / 2, 0.0, PI / 2, PI]
	for c in 4:
		for i in seg + 1:
			var a = a0[c] + (PI / 2) * i / seg
			p.append(cs[c] + Vector2(cos(a), sin(a)) * r)
	return p

static func circle(c: Vector2, r: float, seg := 18) -> PackedVector2Array:
	var p = PackedVector2Array()
	for i in seg:
		p.append(c + Vector2(cos(i * TAU / seg), sin(i * TAU / seg)) * r)
	return p

static func shape(parent: Node, pts: PackedVector2Array, fill: Color, outline := true, w := OUTLINE_W) -> Polygon2D:
	var poly = Polygon2D.new()
	poly.polygon = pts
	poly.color = fill
	parent.add_child(poly)
	if outline:
		var ln = Line2D.new()
		var lp = pts.duplicate()
		lp.append(pts[0])
		ln.points = lp
		ln.width = w
		ln.default_color = NAVY
		ln.joint_mode = Line2D.LINE_JOINT_ROUND
		poly.add_child(ln)
	return poly

static func line(parent: Node, pts: PackedVector2Array, col: Color, w: float) -> Line2D:
	var ln = Line2D.new()
	ln.points = pts
	ln.width = w
	ln.default_color = col
	ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ln.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(ln)
	return ln

static func cargo_color(type: String) -> Color:
	return {"box": AMBER, "crate": BROWN, "barrel": BLUE}.get(type, AMBER)

static func type_from_points(points: int) -> String:
	return ["box", "box", "crate", "barrel"][clamp(points, 0, 3)]

static func build_cargo(type: String) -> Node2D:
	"""Visual matches each package's existing collision box (hit logic untouched):
	BOX 48x48, CRATE 64x64, BARREL 56x72."""
	var n = Node2D.new()
	n.name = "CargoArt"
	match type:
		"crate":
			shape(n, rrect(-32, -32, 64, 64, 5), BROWN)
			var tint = AMBER.darkened(0.25)
			tint.a = 0.75
			for y in [-17.0, 0.0, 17.0]:
				line(n, PackedVector2Array([Vector2(-27, y), Vector2(27, y)]), tint, 3)
			line(n, PackedVector2Array([Vector2(-24, -24), Vector2(24, 24)]), tint, 6)
			line(n, PackedVector2Array([Vector2(24, -24), Vector2(-24, 24)]), tint, 6)
			var fr = Line2D.new()
			var p = rrect(-32, -32, 64, 64, 5); p.append(p[0])
			fr.points = p; fr.width = OUTLINE_W; fr.default_color = NAVY
			n.add_child(fr)
		"barrel":
			# tall rounded cylinder, elliptical top, 2 navy hoops, label pill between hoops
			shape(n, rrect(-28, -36, 56, 72, 16), BLUE)
			var hl = BLUE.lightened(0.35)
			line(n, PackedVector2Array([Vector2(-16, -26), Vector2(-16, 26)]), hl, 5)
			var top = PackedVector2Array()
			for i in 16:
				top.append(Vector2(cos(i * TAU / 16) * 22, -29 + sin(i * TAU / 16) * 5))
			shape(n, top, BLUE.lightened(0.15), true, 3)
			for y in [-14.0, 16.0]:
				line(n, PackedVector2Array([Vector2(-27, y), Vector2(27, y)]), NAVY, 4)
			var pill = shape(n, rrect(-18, -6, 36, 14, 7), NAVY, false)
			_label(n, "BARREL", 10, Vector2(-24, -8), Vector2(48, 18))
		_:
			shape(n, rrect(-24, -24, 48, 48, 4), AMBER)
			shape(n, PackedVector2Array([Vector2(-6, -22), Vector2(6, -22), Vector2(6, 22), Vector2(-6, 22)]), AMBER.darkened(0.2), false)
			shape(n, rrect(-17, -7, 34, 14, 6), NAVY, false)
			_label(n, "BOX", 10, Vector2(-20, -9), Vector2(40, 18))
	return n

static func _label(parent: Node, t: String, size: int, pos: Vector2, sz: Vector2):
	var l = Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)

static func burst(parent: Node, pos: Vector2, tex: Texture2D, col: Color, amount: int, life: float, vmin: float, vmax: float, smin: float, smax: float, grav := Vector2(0, 600), spread := 180.0, dir := Vector2(0, -1)) -> Node2D:
	# Sprite burst: each piece is a white texture (or flat square) tinted by modulate,
	# moved ballistically and faded via tween. Avoids CPUParticles2D color_ramp, which
	# mis-tints particles in the web compatibility renderer.
	var root = Node2D.new()
	root.position = pos
	root.z_index = 70
	parent.add_child(root)
	var base_ang = dir.angle()
	for i in amount:
		var piece: Node2D
		var sc = randf_range(smin, smax)
		if tex != null:
			var sp = Sprite2D.new()
			sp.texture = tex
			piece = sp
			piece.scale = Vector2(sc, sc)
		else:
			var q = Polygon2D.new()
			var h = sc * 0.5
			q.polygon = PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
			piece = q
		piece.modulate = col
		piece.rotation = randf() * TAU
		root.add_child(piece)
		var ang = base_ang + deg_to_rad(randf_range(-spread, spread))
		var v = Vector2.from_angle(ang) * randf_range(vmin, vmax)
		var spin = randf_range(-6.0, 6.0)
		var r0 = piece.rotation
		var tw = piece.create_tween()
		tw.tween_method(func(t: float):
			if is_instance_valid(piece):
				piece.position = v * t + 0.5 * grav * t * t
				piece.rotation = r0 + spin * t
				piece.modulate.a = col.a * (1.0 - t / life), 0.0, life, life)
	parent.get_tree().create_timer(life + 0.1).timeout.connect(func():
		if is_instance_valid(root): root.queue_free())
	return root
