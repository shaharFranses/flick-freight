class_name Screens
extends CanvasLayer
## Modal screens: pause, level results (stars), level select.

signal resume
signal restart
signal next_level
signal open_levels
signal play_level(index: int)
signal close_levels

const NAVY = Color("#1B2A41")
const GOLD = Color("#FFD34E")
const STAR_TEX = preload("res://art/v2/fx/star_gold.png")
const LOCK_TEX = preload("res://art/v2/icons/locked.png")

var root: Control
var current: Control = null


func _ready():
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)


func is_open() -> bool:
	return current != null


func close():
	if current:
		current.queue_free()
		current = null


func _dim() -> Control:
	close()
	var d = ColorRect.new()
	d.color = Color(NAVY, 0.6)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(d)
	current = d
	d.modulate.a = 0.0
	d.create_tween().tween_property(d, "modulate:a", 1.0, 0.18)
	return d


func _card(parent: Control, w: float) -> VBoxContainer:
	var p = PanelContainer.new()
	p.theme_type_variation = "CardPanel"
	p.custom_minimum_size = Vector2(w, 0)
	parent.add_child(p)
	var v = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	p.add_child(v)
	p.modulate.a = 0.0
	_center_card.call_deferred(p)
	return v


func _center_card(p: PanelContainer):
	if not is_instance_valid(p):
		return
	p.reset_size()
	p.position = Vector2(640, 360) - p.size * 0.5
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2(0.88, 0.88)
	p.modulate.a = 1.0
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _title(text: String, size := 52, color := GOLD) -> Label:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, cb: Callable, variation := "") -> Button:
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(190, 70)
	if variation != "":
		b.theme_type_variation = variation
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b


func _row(buttons: Array) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	for b in buttons:
		h.add_child(b)
	return h


# ------------------------------------------------------------------ pause
func show_pause():
	var d = _dim()
	var v = _card(d, 520)
	v.add_child(_title("PAUSED"))
	v.add_child(_button("RESUME", func(): resume.emit(), "BigButton"))
	v.add_child(_row([
		_button("RESTART", func(): restart.emit(), "SecondaryButton"),
		_button("LEVELS", func(): open_levels.emit(), "SecondaryButton")]))


# ------------------------------------------------------------------ results
func show_results(level_index: int, stars: int, delivered: int, total: int):
	var d = _dim()
	var won = stars > 0
	var v = _card(d, 600)
	v.add_child(_title("LEVEL %d COMPLETE!" % (level_index + 1) if won else "NOT QUITE!", 48))
	var star_row = HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override("separation", 14)
	star_row.custom_minimum_size = Vector2(0, 110)
	var star_nodes: Array = []
	for i in 3:
		var tr = TextureRect.new()
		tr.texture = STAR_TEX
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var sz = 96 if i == 1 else 80
		tr.custom_minimum_size = Vector2(sz, sz)
		tr.modulate = Color(0.3, 0.35, 0.45, 1)
		tr.pivot_offset = Vector2(sz, sz) * 0.5
		star_row.add_child(tr)
		star_nodes.append(tr)
	v.add_child(star_row)
	var lv = Levels.get_level(level_index)
	var sub = "Loaded %d of %d" % [delivered, total]
	if not won:
		sub += "  -  you need %d" % lv.goal
	v.add_child(_title(sub, 28, Color.WHITE))
	var buttons: Array = [_button("LEVELS", func(): open_levels.emit(), "SecondaryButton"),
		_button("RETRY", func(): restart.emit(), "SecondaryButton" if won else "BigButton")]
	if won and level_index < Levels.count() - 1:
		buttons.append(_button("NEXT", func(): next_level.emit(), "BigButton"))
	v.add_child(_row(buttons))
	# stars pop in one by one
	var tw = d.create_tween()
	tw.tween_interval(0.35)
	for i in stars:
		var s: TextureRect = star_nodes[i]
		tw.tween_callback(func():
			s.modulate = Color.WHITE
			s.scale = Vector2(1.6, 1.6)
			Sfx.play("deliver", -2.0, 1.0 + 0.15 * i)
			var t2 = s.create_tween()
			t2.tween_property(s, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
		tw.tween_interval(0.3)
	tw.tween_callback(func(): Sfx.play("win" if won else "lose", -3.0))


# ------------------------------------------------------------------ level select
func show_levels(can_close: bool):
	var d = _dim()
	d.color = Color(NAVY, 0.88)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.position = Vector2(140, 40)
	v.custom_minimum_size = Vector2(1000, 0)
	d.add_child(v)
	var head = HBoxContainer.new()
	var t = _title("FLICK FREIGHT", 56)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var total = Label.new()
	total.text = "%d / %d" % [SaveData.total_stars(), Levels.count() * 3]
	total.add_theme_font_size_override("font_size", 34)
	total.add_theme_color_override("font_color", GOLD)
	head.add_child(total)
	var st = TextureRect.new()
	st.texture = STAR_TEX
	st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	st.custom_minimum_size = Vector2(44, 44)
	st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(st)
	v.add_child(head)
	var per_world = {}
	for i in Levels.count():
		var w = Levels.get_level(i).world
		if not per_world.has(w):
			per_world[w] = []
		per_world[w].append(i)
	for w in per_world.keys():
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var wl = Label.new()
		wl.text = Levels.WORLDS[w].name
		wl.custom_minimum_size = Vector2(150, 0)
		wl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		wl.add_theme_font_size_override("font_size", 28)
		wl.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		row.add_child(wl)
		for i in per_world[w]:
			row.add_child(_level_tile(i))
		v.add_child(row)
	if can_close:
		var back = _button("BACK", func(): close_levels.emit(), "SecondaryButton")
		v.add_child(_row([back]))


func _level_tile(i: int) -> Button:
	var b = Button.new()
	b.custom_minimum_size = Vector2(150, 130)
	b.focus_mode = Control.FOCUS_NONE
	var unlocked = SaveData.unlocked(i)
	b.disabled = not unlocked
	b.theme_type_variation = "LevelTile"
	var v = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	b.add_child(v)
	if unlocked:
		var n = Label.new()
		n.text = str(i + 1)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.add_theme_font_size_override("font_size", 48)
		n.add_theme_color_override("font_color", NAVY)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(n)
		var sr = HBoxContainer.new()
		sr.alignment = BoxContainer.ALIGNMENT_CENTER
		sr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s = SaveData.stars(i)
		for k in 3:
			var tr = TextureRect.new()
			tr.texture = STAR_TEX
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(30, 30)
			tr.modulate = Color.WHITE if k < s else Color(0, 0, 0, 0.25)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sr.add_child(tr)
		v.add_child(sr)
		b.pressed.connect(func():
			Sfx.play("click")
			play_level.emit(i))
	else:
		var tr = TextureRect.new()
		tr.texture = LOCK_TEX
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(48, 48)
		tr.modulate = Color(1, 1, 1, 0.6)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tr)
	return b
