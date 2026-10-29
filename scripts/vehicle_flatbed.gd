extends VehicleBase
## V6: flatbed with no sides at all. Stacking and balance: anything that slides goes over the edge.

const BED := 300.0


func _define(_cfg: Dictionary) -> Dictionary:
	var half = BED * 0.5
	return {
		"zone": Rect2(-half + 2, -300, BED - 4, 300),
		"floor_w": BED,
		"floor": Rect2(-half, 0, BED, 18),
		"rear": Rect2(-half - 2, -1, 2, 1),  # no rear wall (a lip the cargo can't catch on)
		"walls": [],
		"front": [PackedVector2Array([Vector2(half + 6, 18), Vector2(half + 6, -112), Vector2(half + 80, -112),
			Vector2(half + 112, -62), Vector2(half + 150, -54), Vector2(half + 150, 18)])],
		"reach": Rect2(-half - 60, -320, BED + 260, 340),
		"ride": 70.0,
		"wheels": [[Vector2(-half + 50, 46), 30.0], [Vector2(half - 50, 46), 30.0], [Vector2(half + 110, 46), 30.0]],
	}


func _draw_front(n: Node2D):
	var half = BED * 0.5
	var body = Color("#8E5BD6")
	n.draw_rect(Rect2(-half - 4, 0, BED + 160, 20), NAVY)
	n.draw_rect(Rect2(-half, 0, BED, 10), Color("#A87444"))
	n.draw_rect(Rect2(-half, 0, BED, 3), Color("#C9945F"))
	for x in range(int(-half) + 30, int(half), 60):
		n.draw_line(Vector2(x, 1), Vector2(x, 9), Color("#7A4E2A"), 2.0)
	var cab = PackedVector2Array([Vector2(half + 6, 18), Vector2(half + 6, -112), Vector2(half + 80, -112),
		Vector2(half + 112, -62), Vector2(half + 150, -54), Vector2(half + 150, 18)])
	n.draw_colored_polygon(Geometry2D.offset_polygon(cab, 3)[0], NAVY)
	n.draw_colored_polygon(cab, body)
	n.draw_rect(Rect2(half + 18, -100, 36, 30), Color("#BFE7F7"))
	n.draw_colored_polygon(PackedVector2Array([Vector2(half + 62, -100), Vector2(half + 76, -100),
		Vector2(half + 100, -66), Vector2(half + 62, -66)]), Color("#BFE7F7"))
	n.draw_rect(Rect2(half + 6, -30, 144, 8), Color(1, 1, 1, 0.85))
