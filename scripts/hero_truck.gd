extends Node2D
# r4 hero truck (visual only). Built under TruckBay; the Area2D hitbox, bay travel and
# hold-centre logic are untouched. Drop zone = the old 110px target (-55..55, y 26..56).
var body: Node2D
var wheels: Array = []
var lip_glow: Polygon2D
var last_x := 0.0
var bob_t := 0.0

func _ready():
	name = "HeroTruck"
	var bay = get_parent()
	for n in ["TruckCab", "TruckBody", "LoadingBedRim", "LeftSideRim", "RightSideRim", "BayOpening", "TargetChevron1", "TargetChevron2", "TargetOutline"]:
		var c = bay.get_node_or_null(n)
		if c: c.visible = false
	z_index = 1
	body = Node2D.new()
	add_child(body)
	# bed
	Art.shape(body, Art.rrect(-92, -50, 184, 84, 10), Art.CORAL)
	Art.shape(body, Art.rrect(-84, -44, 168, 12, 5), Art.CORAL.lightened(0.25), false)
	# cab (right), window, door, FREIGHT decal
	Art.shape(body, Art.rrect(88, -36, 62, 70, 12), Art.CORAL.darkened(0.08))
	Art.shape(body, Art.rrect(100, -28, 40, 24, 6), Art.WHITE)
	Art.line(body, PackedVector2Array([Vector2(98, 2), Vector2(98, 28)]), Art.NAVY, 3)
	var dec = Label.new()
	dec.text = "FREIGHT"
	dec.add_theme_font_size_override("font_size", 18)
	dec.add_theme_color_override("font_color", Art.WHITE)
	dec.add_theme_color_override("font_outline_color", Art.NAVY)
	dec.add_theme_constant_override("outline_size", 4)
	dec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dec.position = Vector2(-70, -30)
	dec.size = Vector2(140, 24)
	dec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(dec)
	# drop zone: navy slot + amber dashed lip
	Art.shape(body, Art.rrect(-55, 24, 110, 34, 6), Art.NAVY, false)
	var x = -55.0
	while x < 55.0:
		Art.line(body, PackedVector2Array([Vector2(x, 24), Vector2(min(x + 10, 55), 24)]), Art.AMBER, 5)
		Art.line(body, PackedVector2Array([Vector2(x, 58), Vector2(min(x + 10, 55), 58)]), Art.AMBER, 3)
		x += 18.0
	lip_glow = Art.shape(body, Art.rrect(-60, 18, 120, 46, 8), Color(Art.MINT, 0.0), false)
	# wheels
	for wx in [-76.0, 120.0]:
		var w = Node2D.new()
		w.position = Vector2(wx, 38)
		Art.shape(w, Art.circle(Vector2.ZERO, 17), Art.NAVY)
		Art.shape(w, Art.circle(Vector2.ZERO, 7), Color("#9AA3B5"), false)
		Art.line(w, PackedVector2Array([Vector2(-11, 0), Vector2(11, 0)]), Color("#9AA3B5"), 3)
		add_child(w)
		wheels.append(w)
	last_x = bay.global_position.x

func _process(delta):
	var gx = get_parent().global_position.x
	var dx = gx - last_x
	last_x = gx
	for w in wheels:
		w.rotation += dx / 17.0
	bob_t += delta * (2.0 + abs(dx) * 0.6)
	body.position.y = sin(bob_t * 6.0) * min(1.5, abs(dx) * 0.4)

func hit_pulse(col: Color):
	lip_glow.color = Color(col, 0.75)
	var tw = create_tween()
	tw.tween_property(lip_glow, "color:a", 0.0, 0.35)
	var tb = create_tween()
	tb.tween_property(body, "scale", Vector2(1.06, 0.92), 0.06)
	tb.tween_property(body, "scale", Vector2(0.98, 1.03), 0.08)
	tb.tween_property(body, "scale", Vector2.ONE, 0.08)
