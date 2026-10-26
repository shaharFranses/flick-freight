class_name Hud
extends CanvasLayer
## In-level HUD: level badge, load progress with star markers, upcoming cargo,
## pause/mute, mechanic banners, score pop-ups and the first-time tutorial.

signal pause_pressed

const NAVY = Color("#1B2A41")
const GOLD = Color("#FFD34E")
const STAR_TEX = preload("res://art/v2/fx/star_gold.png")
const CARGO_TEX = {
	"box": preload("res://art/v2/cargo/box.png"),
	"crate": preload("res://art/v2/cargo/crate.png"),
	"barrel": preload("res://art/v2/cargo/barrel.png"),
	"fragile": preload("res://art/v2/cargo/fragile.png"),
}

var game: Game
var root: Control
var level_label: Label
var world_label: Label
var progress_label: Label
var bar: Control
var queue_box: HBoxContainer
var mute_btn: Button
var banner: PanelContainer
var tutorial: Node2D
var tutorial_label: Label
var _goal := 1
var _s2 := 1
var _total := 1
var _delivered := 0
var _tut_t := 0.0


func _ready():
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)
	_build_top_bar()


func _panel_style(alpha := 0.82, radius := 18) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(NAVY, alpha)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _label(text: String, size: int, color := Color.WHITE) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_top_bar():
	# ---- level badge (left)
	var lp = PanelContainer.new()
	lp.add_theme_stylebox_override("panel", _panel_style())
	lp.position = Vector2(16, 14)
	lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lv = VBoxContainer.new()
	lv.add_theme_constant_override("separation", -4)
	level_label = _label("LEVEL 1", 30)
	world_label = _label("TOWN", 18, Color(1, 1, 1, 0.65))
	lv.add_child(level_label)
	lv.add_child(world_label)
	lp.add_child(lv)
	root.add_child(lp)

	# ---- progress (centre)
	var cp = PanelContainer.new()
	cp.add_theme_stylebox_override("panel", _panel_style())
	cp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cp.custom_minimum_size = Vector2(440, 0)
	cp.position = Vector2(640 - 220, 14)
	var cv = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	var row = HBoxContainer.new()
	progress_label = _label("LOADED 0 / 3", 24)
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(progress_label)
	queue_box = HBoxContainer.new()
	queue_box.add_theme_constant_override("separation", 4)
	queue_box.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(queue_box)
	cv.add_child(row)
	bar = Control.new()
	bar.custom_minimum_size = Vector2(400, 30)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(_draw_bar)
	cv.add_child(bar)
	cp.add_child(cv)
	root.add_child(cp)

	# ---- buttons (right)
	var bh = HBoxContainer.new()
	bh.add_theme_constant_override("separation", 12)
	bh.position = Vector2(1280 - 16 - 64 * 2 - 12, 14)
	var pause = _icon_button("res://art/v2/icons/pause.png")
	pause.pressed.connect(func():
		Sfx.play("click")
		pause_pressed.emit())
	mute_btn = _icon_button("res://art/v2/icons/audioOn.png")
	mute_btn.pressed.connect(_toggle_mute)
	_update_mute_icon()
	bh.add_child(mute_btn)
	bh.add_child(pause)
	root.add_child(bh)


func _icon_button(icon_path: String) -> Button:
	var b = Button.new()
	b.icon = load(icon_path)
	b.expand_icon = true
	b.custom_minimum_size = Vector2(64, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_constant_override("icon_max_width", 40)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.theme_type_variation = "IconButton"
	return b


func _toggle_mute():
	Sfx.inst.toggle_mute()
	_update_mute_icon()
	Sfx.play("click")


func _update_mute_icon():
	if Sfx.inst:
		mute_btn.icon = load("res://art/v2/icons/audioOff.png" if Sfx.inst.muted else "res://art/v2/icons/audioOn.png")


func _draw_bar():
	var w = bar.size.x
	var h = 14.0
	var y = 14.0
	bar.draw_rect(Rect2(0, y, w, h), Color(1, 1, 1, 0.15))
	var f = float(_delivered) / _total
	if f > 0:
		bar.draw_rect(Rect2(0, y, w * f, h), Color("#3DDC97"))
	for m in [_goal, _s2, _total]:
		var x = w * float(m) / _total
		var reached = _delivered >= m
		var sz = 26.0
		var r = Rect2(clamp(x - sz * 0.5, 0, w - sz), y + h * 0.5 - sz * 0.5, sz, sz)
		bar.draw_texture_rect(STAR_TEX, r, false, Color(1, 1, 1) if reached else Color(0.35, 0.4, 0.5, 1))


# ----------------------------------------------------------------- binding
func bind(g: Game):
	game = g
	var lv = g.level
	_goal = lv.goal
	_s2 = lv.get("s2", lv.cargo.length())
	_total = lv.cargo.length()
	_delivered = 0
	level_label.text = "LEVEL %d" % (g.level_index + 1)
	world_label.text = Levels.world_of(g.level_index).name
	g.progress_changed.connect(_on_progress)
	g.queue_changed.connect(_on_queue)
	g.popup.connect(show_popup)
	g.first_throw.connect(_hide_tutorial)
	_on_progress(0, _total)
	if lv.has("intro"):
		show_banner(lv.intro.title, lv.intro.text, lv.intro.get("icon", ""))
	elif lv.get("wind", 0) != 0:
		show_banner("WIND", "Wind is blowing %s." % ("toward the truck" if lv.wind > 0 else "against you"), "wind")
	else:
		show_banner("LEVEL %d" % (g.level_index + 1), "Load %d of %d to pass" % [_goal, _total], "", 1.6)
	if lv.get("tutorial", false) and not SaveData.get_flag("tutorial_done", false):
		_show_tutorial()


func _on_progress(d: int, _left: int):
	_delivered = d
	progress_label.text = "LOADED %d / %d" % [d, _goal]
	if d >= _goal:
		progress_label.add_theme_color_override("font_color", Color("#3DDC97"))
	bar.queue_redraw()


func _on_queue(types: Array):
	for c in queue_box.get_children():
		c.queue_free()
	var n = 0
	for t in types:
		var tr = TextureRect.new()
		tr.texture = CARGO_TEX[t]
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(26, 26) if n > 0 else Vector2(32, 32)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_box.add_child(tr)
		n += 1
		if n >= 7:
			if types.size() > 7:
				queue_box.add_child(_label("+%d" % (types.size() - 7), 20))
			break


# ----------------------------------------------------------------- pop-ups
func show_popup(text: String, pos: Vector2, color: Color, size: int):
	var l = _label(text, size, color)
	l.add_theme_color_override("font_outline_color", NAVY)
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(l)
	l.reset_size()
	l.pivot_offset = l.size * 0.5
	l.position = pos - l.size * 0.5
	l.scale = Vector2(0.4, 0.4)
	var tw = l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 50, 0.7).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.3)
	tw.tween_callback(l.queue_free)


func show_banner(title: String, text: String, icon := "", hold := 3.2):
	if banner and is_instance_valid(banner):
		banner.queue_free()
	banner = PanelContainer.new()
	banner.add_theme_stylebox_override("panel", _panel_style(0.9, 22))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	if icon in CARGO_TEX:
		var tr = TextureRect.new()
		tr.texture = CARGO_TEX[icon]
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(60, 60)
		h.add_child(tr)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var t = _label(title, 36, GOLD)
	v.add_child(t)
	if text != "":
		v.add_child(_label(text, 24))
	h.add_child(v)
	banner.add_child(h)
	root.add_child(banner)
	banner.reset_size()
	banner.position = Vector2(640 - banner.size.x * 0.5, 118)
	banner.modulate.a = 0.0
	var tw = banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(hold)
	tw.tween_property(banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(banner.queue_free)


# ----------------------------------------------------------------- tutorial
func _show_tutorial():
	tutorial = Node2D.new()
	tutorial.draw.connect(_draw_tutorial)
	root.add_child(tutorial)
	tutorial_label = _label("DRAG BACK & RELEASE TO THROW", 30, Color.WHITE)
	tutorial_label.add_theme_color_override("font_outline_color", NAVY)
	tutorial_label.add_theme_constant_override("outline_size", 10)
	root.add_child(tutorial_label)
	tutorial_label.reset_size()
	tutorial_label.position = Vector2(60, 250)


func _hide_tutorial():
	SaveData.set_flag("tutorial_done", true)
	if tutorial:
		tutorial.queue_free()
		tutorial = null
	if tutorial_label:
		tutorial_label.queue_free()
		tutorial_label = null


func _process(delta: float):
	if tutorial:
		_tut_t += delta
		tutorial.queue_redraw()


func _draw_tutorial():
	if game == null or game.current == null or not game.current_ready:
		return
	# a finger presses the cargo, drags down-left, lets go; dotted arc shows the result
	var start = game.rest_pos
	var cyc = fmod(_tut_t, 2.2) / 2.2
	var drag = Vector2(-120, 70)
	var k = clamp((cyc - 0.15) / 0.5, 0.0, 1.0)
	k = k * k * (3 - 2 * k)
	var finger = start + drag * k
	var pressed = cyc > 0.1 and cyc < 0.72
	if cyc > 0.72:
		finger = start + drag + Vector2(0, -20) * (cyc - 0.72) * 4
	var a = 1.0 if cyc < 0.9 else (1.0 - (cyc - 0.9) * 10)
	# arc preview
	if pressed and k > 0.05:
		var v = -drag * k * Game.POWER
		var p = start
		for i in 24:
			v += Vector2(0, Game.GRAVITY) / 60.0 * 3
			p += v / 60.0 * 3
			if i % 2 == 0:
				tutorial.draw_circle(p, 6.5, Color(NAVY, 0.6 * a))
				tutorial.draw_circle(p, 4.5, Color(1, 1, 1, 0.8 * a))
	# finger: ring + dot
	tutorial.draw_circle(finger, 30 if pressed else 36, Color(1, 1, 1, 0.25 * a))
	tutorial.draw_arc(finger, 30 if pressed else 36, 0, TAU, 32, Color(1, 1, 1, 0.95 * a), 5.0)
	tutorial.draw_circle(finger, 12, Color(1, 1, 1, 0.95 * a))
