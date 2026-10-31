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
	v.add_child(_title("LEVEL %d COMPLETE!" % Levels.number_of(level_index) if won else "NOT QUITE!", 48))
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
	if lv.has("need"):
		var ts: Array = lv.get("throw_stars", [lv.need, lv.need + 1])
		var thrown = get_parent().game.thrown if get_parent().game else 0
		sub = "%d loaded in %d throws  -  %d throws for 3 stars" % [delivered, thrown, ts[0]]
	v.add_child(_title(sub, 28, Color.WHITE))
	var buttons: Array = [_button("LEVELS", func(): open_levels.emit(), "SecondaryButton"),
		_button("RETRY", func(): restart.emit(), "SecondaryButton" if won else "BigButton")]
	if won and Levels.next_of(level_index) >= 0 and Levels.unlocked(Levels.next_of(level_index)):
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
	v.position = Vector2(140, 28)
	v.custom_minimum_size = Vector2(1000, 0)
	d.add_child(v)
	var head = HBoxContainer.new()
	var t = _title("FLICK FREIGHT", 56)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var total = Label.new()
	total.text = "%d / %d" % [SaveData.total_stars(), Levels.order().size() * 3]
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
	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	v.add_child(page)
	_levels_page = page
	_fill_world_page(Levels.get_level(get_parent().level_index).world)  # open on the current world
	if can_close:
		var back = _button("BACK", func(): close_levels.emit(), "SecondaryButton")
		v.add_child(_row([back]))


var _levels_page: VBoxContainer


## One world per page (arrows flip through Levels.WORLD_ORDER): its Act I, then Act II.
func _fill_world_page(w: int):
	for c in _levels_page.get_children():
		c.queue_free()
	var ids = Levels.levels_in_world_ordered(w)
	var wk = Levels.WORLD_ORDER.find(w)
	var nav = HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 24)
	var prev = _arrow_button(true)
	prev.disabled = wk <= 0
	prev.pressed.connect(func():
		Sfx.play("click")
		_fill_world_page(Levels.WORLD_ORDER[wk - 1]))
	nav.add_child(prev)
	if Levels.WORLDS[w].has("icon"):
		nav.add_child(WorldIcons.make(Levels.WORLDS[w].icon))  # the world's special vehicle
	var name_box = VBoxContainer.new()
	name_box.custom_minimum_size = Vector2(420, 0)
	name_box.add_theme_constant_override("separation", -6)
	var wl = _title(Levels.WORLDS[w].name, 44, Color.WHITE)
	name_box.add_child(wl)
	var got = 0
	for i in ids:
		got += SaveData.stars(i)
	var sl = _title("WORLD %d   %d / %d STARS" % [wk + 1, got, ids.size() * 3], 22, GOLD)
	name_box.add_child(sl)
	nav.add_child(name_box)
	var nxt = _arrow_button(false)
	nxt.disabled = wk >= Levels.WORLD_ORDER.size() - 1
	nxt.pressed.connect(func():
		Sfx.play("click")
		_fill_world_page(Levels.WORLD_ORDER[wk + 1]))
	nav.add_child(nxt)
	_levels_page.add_child(nav)
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	var center = CenterContainer.new()
	center.add_child(grid)
	_levels_page.add_child(center)
	var compact = ids.size() > 10  # Act II makes three rows: smaller tiles
	for i in ids:
		grid.add_child(_level_tile(i, compact))
	if not ids.is_empty() and not SaveData.unlocked(ids[0]) and wk > 0:
		var before = Levels.WORLD_ORDER[wk - 1]
		var left = Levels.levels_in_world_ordered(before).filter(func(j): return SaveData.stars(j) == 0).size()
		var msg = "Win every %s level to unlock (%d to go)" % [Levels.WORLDS[before].name, left]
		_levels_page.add_child(_title(msg, 26, Color(1, 1, 1, 0.75)))


func _arrow_button(left: bool) -> Button:
	var b = Button.new()
	b.icon = load("res://art/v2/icons/right.png")
	b.expand_icon = true
	b.custom_minimum_size = Vector2(76, 76)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_constant_override("icon_max_width", 44)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.theme_type_variation = "IconButton"
	if left:
		var img: Image = b.icon.get_image()
		img.flip_x()
		b.icon = ImageTexture.create_from_image(img)
	return b


func _level_tile(i: int, compact := false) -> Button:
	var b = Button.new()
	b.custom_minimum_size = Vector2(150, 108 if compact else 130)
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
		n.text = str(Levels.number_of(i))
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
