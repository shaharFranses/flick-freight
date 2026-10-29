class_name WorldIcons
extends Control
## Small code-drawn picture of a world's special vehicle, next to its name on the level
## select page (Plan 2 §4.4), so players can see the helicopter waiting at the end.
## Drawn in a 96 x 56 box.

const NAVY = Color("#1B2A41")
var kind := ""


static func make(k: String) -> WorldIcons:
	var c = WorldIcons.new()
	c.kind = k
	c.custom_minimum_size = Vector2(96, 56)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _draw():
	match kind:
		"moto":
			_wheel(Vector2(22, 44), 11)
			_wheel(Vector2(74, 44), 11)
			draw_colored_polygon(PackedVector2Array([Vector2(22, 40), Vector2(40, 26), Vector2(66, 26), Vector2(76, 40)]), Color("#E4572E"))
			draw_rect(Rect2(10, 14, 26, 18), Color("#C98E4A"))
			draw_circle(Vector2(58, 16), 7, NAVY)
		"pickup":
			draw_rect(Rect2(6, 26, 50, 14), Color("#3D8BDB"))
			draw_colored_polygon(PackedVector2Array([Vector2(56, 40), Vector2(56, 14), Vector2(76, 14), Vector2(90, 28), Vector2(90, 40)]), Color("#3D8BDB"))
			draw_rect(Rect2(62, 18, 14, 10), Color("#BFE7F7"))
			_wheel(Vector2(22, 44), 9)
			_wheel(Vector2(76, 44), 9)
		"dump":
			draw_set_transform(Vector2(30, 34), -0.25, Vector2.ONE)
			draw_rect(Rect2(-26, -16, 52, 16), Color("#F2B134"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_colored_polygon(PackedVector2Array([Vector2(60, 40), Vector2(60, 12), Vector2(78, 12), Vector2(90, 26), Vector2(90, 40)]), Color("#F2B134"))
			draw_rect(Rect2(4, 36, 86, 6), NAVY)
			_wheel(Vector2(18, 46), 8)
			_wheel(Vector2(46, 46), 8)
			_wheel(Vector2(78, 46), 8)
		"ferry":
			draw_rect(Rect2(4, 36, 88, 14), Color("#4F9FD9"))
			draw_colored_polygon(PackedVector2Array([Vector2(8, 34), Vector2(88, 34), Vector2(80, 46), Vector2(16, 46)]), Color("#E4572E"))
			draw_rect(Rect2(20, 18, 40, 16), Color("#8A5A32"))
			draw_rect(Rect2(60, 12, 18, 22), Color("#E4572E"))
		"lift":
			draw_line(Vector2(0, 8), Vector2(96, 22), NAVY, 3.0)
			draw_line(Vector2(48, 15), Vector2(48, 38), NAVY, 3.0)
			draw_rect(Rect2(28, 38, 40, 6), Color("#E4572E"))
			draw_rect(Rect2(28, 22, 5, 18), Color("#E4572E"))
		"flatcar":
			draw_rect(Rect2(4, 30, 88, 8), Color("#7F8EA3"))
			draw_rect(Rect2(14, 14, 28, 16), Color("#C98E4A"))
			draw_rect(Rect2(48, 14, 28, 16), Color("#C98E4A"))
			for x in [16, 32, 64, 80]:
				_wheel(Vector2(x, 44), 7)
		"heli":
			draw_line(Vector2(6, 6), Vector2(90, 6), NAVY, 4.0)
			draw_rect(Rect2(46, 6, 4, 6), NAVY)
			draw_colored_polygon(PackedVector2Array([Vector2(30, 24), Vector2(38, 12), Vector2(64, 12), Vector2(72, 24), Vector2(66, 32), Vector2(34, 32)]), Color("#E4572E"))
			draw_rect(Rect2(4, 16, 30, 5), Color("#B8401F"))
			draw_rect(Rect2(54, 15, 12, 8), Color("#BFE7F7"))
			draw_line(Vector2(50, 32), Vector2(40, 46), NAVY, 2.0)
			draw_line(Vector2(50, 32), Vector2(62, 46), NAVY, 2.0)
			draw_rect(Rect2(36, 44, 30, 9), Color("#E8D9B0"))
			draw_rect(Rect2(36, 44, 30, 9), NAVY, false, 2.0)


func _wheel(c: Vector2, r: float):
	draw_circle(c, r, NAVY)
	draw_circle(c, r * 0.45, Color("#C9CED6"))
