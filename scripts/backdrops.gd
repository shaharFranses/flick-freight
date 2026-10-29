class_name Backdrops
extends RefCounted
## Code-drawn backgrounds for the worlds after Desert (no external art needed).
## Kept light and muted so cargo, trucks and obstacles stay readable at 907x510.

const TOP := -300.0
const HORIZON := 470.0


static func draw(n: Node2D, kind: String):
	match kind:
		"harbor":
			_sky(n, Color("#7CC8F0"), Color("#DDF3FB"))
			_harbor(n)
		"snow":
			_sky(n, Color("#9CC3E6"), Color("#EAF4FB"))
			_snow(n)
		"yard":
			_sky(n, Color("#F2A65A"), Color("#FBE3C4"))
			_yard(n)
		"sky":
			_sky(n, Color("#4F8FE0"), Color("#CFE7FB"))
			_skyport(n)


static func _sky(n: Node2D, top: Color, bottom: Color):
	n.draw_polygon(PackedVector2Array([Vector2(-50, TOP), Vector2(1330, TOP), Vector2(1330, 720), Vector2(-50, 720)]),
		PackedColorArray([top, top, bottom, bottom]))


static func _sun(n: Node2D, c: Vector2, col: Color):
	n.draw_circle(c, 70, Color(col, 0.25))
	n.draw_circle(c, 48, col)


static func _crane(n: Node2D, x: float, base: float, h: float, col: Color, facing := 1.0):
	var w = 16.0
	n.draw_rect(Rect2(x - w * 0.5, base - h, w, h), col)
	var y = base - h
	# boom: reaches 220 px out over the water on the `facing` side
	var boom_x = x - 40 if facing > 0 else x - 220
	n.draw_rect(Rect2(boom_x, y - 12, 260, 12), col)
	n.draw_rect(Rect2(x - 26, y - 46, 52, 34), col.darkened(0.1))
	var tip = x + 200 * facing
	n.draw_line(Vector2(tip, y), Vector2(tip, y + 120), col.darkened(0.2), 3.0)
	n.draw_rect(Rect2(tip - 14, y + 120, 28, 10), col.darkened(0.2))
	var k = 0.0
	while k < h - 20:
		n.draw_line(Vector2(x - w * 0.5, base - k), Vector2(x + w * 0.5, base - k - 20), col.darkened(0.15), 2.0)
		k += 24.0


static func _harbor(n: Node2D):
	_sun(n, Vector2(1060, 90), Color("#FFF1B8"))
	# sea
	n.draw_rect(Rect2(-50, HORIZON - 40, 1380, 400), Color("#4F9FD9"))
	n.draw_rect(Rect2(-50, HORIZON - 40, 1380, 6), Color("#9BD0F2"))
	for i in 14:
		var x = fmod(i * 173.0, 1300.0)
		var y = HORIZON - 10 + (i % 4) * 26
		n.draw_line(Vector2(x, y), Vector2(x + 44, y), Color(1, 1, 1, 0.35), 3.0)
	# container ship on the horizon
	var sx = 560.0
	var sy = HORIZON - 40
	n.draw_colored_polygon(PackedVector2Array([Vector2(sx, sy - 34), Vector2(sx + 470, sy - 34),
		Vector2(sx + 440, sy), Vector2(sx + 24, sy)]), Color("#3B5573"))
	var cols = [Color("#E79A7F"), Color("#8DB7DE"), Color("#EBC877"), Color("#9FCFAE")]
	for i in 9:
		for j in 2:
			n.draw_rect(Rect2(sx + 40 + i * 42, sy - 64 - j * 28, 38, 26), cols[(i + j * 3) % cols.size()])
	n.draw_rect(Rect2(sx + 420, sy - 96, 34, 62), Color("#DDE5EE"))
	# cranes
	_crane(n, 380, HORIZON - 40, 300, Color("#E8955E"))
	_crane(n, 1220, HORIZON - 40, 260, Color("#E8955E"), -1.0)
	# gulls
	for g in [Vector2(260, 120), Vector2(300, 150), Vector2(820, 70)]:
		n.draw_polyline(PackedVector2Array([g + Vector2(-12, -4), g, g + Vector2(12, -4)]), Color("#4A5568"), 3.0)


static func _snow(n: Node2D):
	_sun(n, Vector2(980, 110), Color("#FFFDF0"))
	var far = Color("#B9D3EA")
	var near = Color("#D6E6F4")
	for m in [[-60.0, 250.0, 330.0], [260.0, 160.0, 380.0], [640.0, 230.0, 360.0], [960.0, 140.0, 420.0]]:
		var x = m[0]
		var top = m[1]
		var w = m[2]
		n.draw_colored_polygon(PackedVector2Array([Vector2(x, HORIZON), Vector2(x + w * 0.5, top), Vector2(x + w, HORIZON)]), far)
		n.draw_colored_polygon(PackedVector2Array([Vector2(x + w * 0.5 - 46, top + 60), Vector2(x + w * 0.5, top),
			Vector2(x + w * 0.5 + 46, top + 60), Vector2(x + w * 0.5 + 14, top + 48), Vector2(x + w * 0.5 - 12, top + 62)]), Color.WHITE)
	n.draw_rect(Rect2(-50, HORIZON - 20, 1380, 400), near)
	for i in 16:
		var x = 20.0 + i * 84.0 + (i % 3) * 18.0
		var y = HORIZON + 10 + (i % 2) * 22.0
		var h = 70.0 + (i % 4) * 16.0
		n.draw_rect(Rect2(x - 4, y - 8, 8, 14), Color("#6B5847"))
		for k in 3:
			var ty = y - 8 - k * h * 0.28
			var hw = (h * 0.32) * (1.0 - k * 0.25)
			n.draw_colored_polygon(PackedVector2Array([Vector2(x - hw, ty), Vector2(x, ty - h * 0.42), Vector2(x + hw, ty)]), Color("#4F7F6A"))
			n.draw_colored_polygon(PackedVector2Array([Vector2(x - hw * 0.45, ty - h * 0.24), Vector2(x, ty - h * 0.42),
				Vector2(x + hw * 0.45, ty - h * 0.24)]), Color.WHITE)


static func _yard(n: Node2D):
	_sun(n, Vector2(1000, 150), Color("#FFE2A8"))
	n.draw_rect(Rect2(-50, HORIZON - 20, 1380, 400), Color("#C9B9A3"))
	var cols = [Color("#C9826B"), Color("#7FA3C2"), Color("#D4B26A"), Color("#8FB59A"), Color("#A88BB8")]
	var x = 330.0
	var i = 0
	while x < 1300:
		var stack = 1 + (i * 7) % 3
		for j in stack:
			var r = Rect2(x, HORIZON - 20 - (j + 1) * 46, 120, 44)
			n.draw_rect(r, cols[(i + j * 2) % cols.size()])
			for k in 5:
				n.draw_line(Vector2(r.position.x + 12 + k * 22, r.position.y + 6), Vector2(r.position.x + 12 + k * 22, r.end.y - 6),
					Color(0, 0, 0, 0.12), 3.0)
		x += 128.0
		i += 1
	_crane(n, 600, HORIZON - 20, 330, Color("#D9A441"))
	# floodlight
	n.draw_rect(Rect2(1180, HORIZON - 360, 10, 340), Color("#6B7684"))
	n.draw_rect(Rect2(1150, HORIZON - 376, 70, 22), Color("#4A5568"))
	for k in 3:
		n.draw_circle(Vector2(1164 + k * 21, HORIZON - 365), 7, Color("#FFF3C4"))


## Sky Port: a cliff-top heliport above a sea of clouds, peaks poking through.
static func _skyport(n: Node2D):
	_sun(n, Vector2(1010, 120), Color("#FFF6D8"))
	for m in [[380.0, 300.0, 300.0], [700.0, 250.0, 380.0], [1040.0, 320.0, 300.0]]:
		var x = m[0]
		var top = m[1]
		var w = m[2]
		n.draw_colored_polygon(PackedVector2Array([Vector2(x, HORIZON + 20), Vector2(x + w * 0.5, top), Vector2(x + w, HORIZON + 20)]), Color("#8FA9C9"))
		n.draw_colored_polygon(PackedVector2Array([Vector2(x + w * 0.5 - 34, top + 44), Vector2(x + w * 0.5, top),
			Vector2(x + w * 0.5 + 34, top + 44), Vector2(x + w * 0.5 + 8, top + 36)]), Color("#F4F8FF"))
	# the cloud sea: rows of puffs, paler toward the front
	for row in 3:
		var y = HORIZON - 30 + row * 34.0
		var col = Color("#E3EEFA").lerp(Color.WHITE, row * 0.4)
		var x = -60.0 + row * 37.0
		var k = 0
		while x < 1360:
			var r = 46.0 + ((k * 13 + row * 7) % 5) * 9.0
			n.draw_circle(Vector2(x, y + 18), r, col)
			x += r * 1.3
			k += 1
		n.draw_rect(Rect2(-50, y + 18, 1380, 400), col)
	# small far helipad marker + windsock on the cliff edge
	n.draw_rect(Rect2(300, HORIZON + 40, 3, 60), Color("#5B6B80"))
	n.draw_colored_polygon(PackedVector2Array([Vector2(303, HORIZON + 42), Vector2(334, HORIZON + 47), Vector2(334, HORIZON + 55),
		Vector2(303, HORIZON + 58)]), Color("#F26B4E"))
