class_name UiTheme
extends RefCounted
## Shared UI theme (Kenney Future font, chunky amber buttons, navy cards).

const NAVY = Color("#1B2A41")
const AMBER = Color("#F2B134")
static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func _flat(bg: Color, radius := 16, bottom := 0, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_width_bottom = bottom
	sb.border_color = border
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8 + bottom
	return sb


static func _button_styles(t: Theme, type: String, base: Color, text: Color, font_size: int):
	var dark = base.darkened(0.25)
	if type != "Button":
		t.set_type_variation(type, "Button")
	t.set_stylebox("normal", type, _flat(base, 18, 6, dark))
	t.set_stylebox("hover", type, _flat(base.lightened(0.12), 18, 6, dark))
	var pressed = _flat(base.darkened(0.05), 18, 2, dark)
	pressed.content_margin_top = 12
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("disabled", type, _flat(Color(base, 0.35), 18, 6, Color(dark, 0.35)))
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_color("font_color", type, text)
	t.set_color("font_hover_color", type, text)
	t.set_color("font_pressed_color", type, text)
	t.set_color("font_disabled_color", type, Color(text, 0.4))
	t.set_font_size("font_size", type, font_size)


static func _build() -> Theme:
	var t = Theme.new()
	var font: FontFile = load("res://art/v2/kenney_future.ttf")
	font.multichannel_signed_distance_field = true
	t.default_font = font
	t.default_font_size = 26
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", NAVY)
	_button_styles(t, "Button", AMBER, NAVY, 30)
	_button_styles(t, "BigButton", AMBER, NAVY, 34)
	_button_styles(t, "SecondaryButton", Color("#E9EEF4"), NAVY, 28)
	_button_styles(t, "LevelTile", Color("#E9EEF4"), NAVY, 28)
	_button_styles(t, "IconButton", Color(NAVY, 0.85), Color.WHITE, 24)
	for s in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = t.get_stylebox(s, "IconButton")
		sb.border_width_bottom = 0
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
	t.set_color("icon_normal_color", "IconButton", Color.WHITE)
	t.set_color("icon_hover_color", "IconButton", Color.WHITE)
	t.set_color("icon_pressed_color", "IconButton", Color(1, 1, 1, 0.8))
	var card = _flat(NAVY, 28)
	card.border_width_left = 4
	card.border_width_right = 4
	card.border_width_top = 4
	card.border_width_bottom = 4
	card.border_color = Color(1, 1, 1, 0.12)
	card.content_margin_left = 36
	card.content_margin_right = 36
	card.content_margin_top = 30
	card.content_margin_bottom = 30
	card.shadow_color = Color(0, 0, 0, 0.3)
	card.shadow_size = 18
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", card)
	return t
