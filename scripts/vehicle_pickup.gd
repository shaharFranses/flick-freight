extends VehicleBase
## V2: pickup truck. Short bed with low sides: soft throws stay in, hard ones slide out the back.

const BED := 240.0
const SIDE := 28.0


func _define(_cfg: Dictionary) -> Dictionary:
	var half = BED * 0.5
	return {
		"zone": Rect2(-half + 2, -300, BED - 4, 300),
		"floor_w": BED,
		"floor": Rect2(-half - 8, 0, BED + 16, 14),
		"rear": Rect2(-half - 8, -SIDE, 8, SIDE),
		"walls": [Rect2(half, -80, 10, 80)],  # cab back: boxes lean on it, not on the cab roof
		"front": [PackedVector2Array([Vector2(half + 12, 14), Vector2(half + 12, -86), Vector2(half + 70, -86),
			Vector2(half + 100, -40), Vector2(half + 140, -34), Vector2(half + 140, 14)])],
		"reach": Rect2(-half - 60, -320, BED + 240, 340),
		"ride": 66.0,
		"wheels": [[Vector2(-half + 40, 40), 28.0], [Vector2(half + 100, 40), 28.0]],
	}


func _draw_back(n: Node2D):
	var half = BED * 0.5
	n.draw_rect(Rect2(-half, -SIDE, BED, SIDE), Color("#7A4E2A"))


func _draw_front(n: Node2D):
	var half = BED * 0.5
	var body = Color("#3D8BDB")
	var dark = Color("#2A6BB0")
	n.draw_rect(Rect2(-half - 10, 0, BED + 150, 16), NAVY)
	n.draw_rect(Rect2(-half - 8, -SIDE, BED + 16, SIDE + 2), dark)
	n.draw_rect(Rect2(-half - 6, -SIDE + 2, BED + 12, SIDE - 4), body)
	n.draw_rect(Rect2(-half - 6, -SIDE + 2, BED + 12, 5), body.lightened(0.25))
	n.draw_rect(Rect2(half - 2, -80, 12, 82), dark)  # cab back wall
	var cab = PackedVector2Array([Vector2(half + 12, 14), Vector2(half + 12, -86), Vector2(half + 70, -86),
		Vector2(half + 100, -40), Vector2(half + 140, -34), Vector2(half + 140, 14)])
	n.draw_colored_polygon(Geometry2D.offset_polygon(cab, 3)[0], NAVY)
	n.draw_colored_polygon(cab, body)
	n.draw_colored_polygon(PackedVector2Array([Vector2(half + 56, -78), Vector2(half + 68, -78),
		Vector2(half + 92, -44), Vector2(half + 56, -44)]), Color("#BFE7F7"))
	n.draw_rect(Rect2(half + 20, -78, 30, 32), Color("#BFE7F7"))
	n.draw_rect(Rect2(half + 128, -28, 12, 10), Color("#FFE27A"))
