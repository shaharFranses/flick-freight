extends SceneTree
## Renders the CrazyGames cover images from the real game art.
##   godot --rendering-driver opengl3 -s res://tools/cover.gd -- --out=covers
## Writes cover_landscape_1920x1080.png, cover_portrait_800x1200.png, cover_square_800x800.png

const SHOTS = [
	# name, size, world-space rect to frame (x, y, w, h), title lines, title y (fraction of height)
	["cover_landscape_1920x1080", Vector2i(1920, 1080), Rect2(40, -40, 1240, 697.5), ["FLICK FREIGHT"], 0.08],
	["cover_portrait_800x1200", Vector2i(800, 1200), Rect2(565, -250, 650, 975), ["FLICK", "FREIGHT"], 0.06],
	["cover_square_800x800", Vector2i(800, 800), Rect2(470, -40, 760, 760), ["FLICK", "FREIGHT"], 0.05],
]

var out_dir := "covers"
var i := 0
var frames := 0
var vp: SubViewport


func _init():
	for a in OS.get_cmdline_user_args():
		var p = a.trim_prefix("--").split("=")
		if p[0] == "out" and p.size() > 1:
			out_dir = p[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_build(SHOTS[0])


func _build(shot):
	if vp:
		vp.queue_free()
	vp = SubViewport.new()
	vp.size = shot[1]
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.physics_object_picking = false
	root.add_child(vp)
	var frame: Rect2 = shot[2]
	var world = Node2D.new()
	vp.add_child(world)
	var cam = Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	cam.position = frame.position
	cam.zoom = Vector2(shot[1].x / frame.size.x, shot[1].y / frame.size.y)
	world.add_child(cam)
	cam.make_current()
	# real level scenery
	var g = Game.new()
	g.setup(5)  # woods, with a pillar
	g.set_process(false)
	world.add_child(g)
	# a parked truck with cargo
	var t = Truck.new()
	t.setup({"x": 900, "amp": 0}, 0, 56)
	t.position = Vector2(900, Game.ROAD_Y - Truck.FLOOR_T - 18 - Truck.WHEEL_R)
	t.set_physics_process(false)
	world.add_child(t)
	_sprite(world, "box", Vector2(800, t.position.y - 30), 0.0)
	_sprite(world, "crate", Vector2(866, t.position.y - 31), 0.0)
	_sprite(world, "barrel", Vector2(930, t.position.y - 32), 0.0)
	_sprite(world, "box", Vector2(835, t.position.y - 90), 0.12)
	# cargo mid-flight along a dotted arc from the dock
	var arc = Node2D.new()
	arc.z_index = 30
	world.add_child(arc)
	var pts: Array = []
	var p = Vector2(Game.FLICK_X, Game.DOCK_TOP - 30)
	var v = Vector2(560, -820)
	for k in 70:
		v += Vector2(0, Game.GRAVITY) / 60.0
		p += v / 60.0
		pts.append(p)
	arc.draw.connect(func():
		for k in range(4, 62, 4):
			arc.draw_circle(pts[k], 8.5, Color(0.106, 0.165, 0.255, 0.75))
			arc.draw_circle(pts[k], 6.0, Color(1, 1, 1, 0.95)))
	_sprite(world, "fragile", pts[67], -0.5, 1.15)
	_sprite(world, "box", Vector2(Game.FLICK_X, Game.DOCK_TOP - 30), 0.0)
	# speed streaks behind the flying cargo
	var fx = Node2D.new()
	fx.z_index = 29
	world.add_child(fx)
	fx.draw.connect(func():
		for k in 3:
			var a = pts[67 - 4 - k * 2]
			var b = pts[67 - 10 - k * 2]
			fx.draw_line(a + Vector2(0, (k - 1) * 14), b + Vector2(0, (k - 1) * 14), Color(1, 1, 1, 0.8), 5.0))
	# title
	var layer = CanvasLayer.new()
	vp.add_child(layer)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", -int(shot[1].x * 0.03))
	box.position = Vector2(0, shot[1].y * shot[4])
	box.size = Vector2(shot[1].x, 0)
	layer.add_child(box)
	var size = int(shot[1].x * (0.115 if shot[3].size() == 1 else 0.19))
	for line in shot[3]:
		var l = Label.new()
		l.text = line
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.theme = UiTheme.get_theme()
		l.add_theme_font_size_override("font_size", size)
		l.add_theme_color_override("font_color", Color("#FFD34E"))
		l.add_theme_color_override("font_outline_color", Color("#1B2A41"))
		l.add_theme_constant_override("outline_size", int(size * 0.2))
		l.add_theme_color_override("font_shadow_color", Color(0.106, 0.165, 0.255, 0.55))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", int(size * 0.09))
		l.add_theme_constant_override("shadow_outline_size", int(size * 0.2))
		l.custom_minimum_size = Vector2(shot[1].x, 0)
		box.add_child(l)
	box.rotation = -0.035
	box.pivot_offset = Vector2(shot[1].x * 0.5, 0)
	frames = 0


func _sprite(parent: Node, kind: String, pos: Vector2, rot: float, scale := 1.0):
	var s = Sprite2D.new()
	var tex: Texture2D = load(Cargo.TYPES[kind].tex)
	s.texture = tex
	s.scale = Cargo.TYPES[kind].size / tex.get_size() * scale
	s.position = pos
	s.rotation = rot
	s.z_index = 0
	parent.add_child(s)


func _process(_d) -> bool:
	frames += 1
	if frames < 8:
		return false
	var shot = SHOTS[i]
	var img = vp.get_texture().get_image()
	var path = "%s/%s.png" % [out_dir, shot[0]]
	img.save_png(path)
	print("saved ", path, " ", img.get_size())
	i += 1
	if i >= SHOTS.size():
		quit()
		return true
	_build(SHOTS[i])
	return false
