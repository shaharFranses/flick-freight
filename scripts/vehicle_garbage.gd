extends VehicleBase
## V3: garbage truck. A deep container with a small hopper opening on top at the rear; the
## rest of the top is roofed. Cargo has to drop in on a steep arc, like a basketball shot.

const IN_W := 200.0  # inside width
const DEPTH := 120.0
const OPEN_W := 140.0  # hopper opening, from the rear wall


func _define(_cfg: Dictionary) -> Dictionary:
	var half = IN_W * 0.5
	var roof_x = -half + OPEN_W
	return {
		"zone": Rect2(-half + 2, -DEPTH, IN_W - 4, DEPTH),
		"floor_w": IN_W,
		"aim_x": -half + OPEN_W * 0.5,  # the bot aims into the opening, not under the roof
		"floor": Rect2(-half - 12, 0, IN_W + 24, 16),
		"rear": Rect2(-half - 12, -DEPTH - 8, 12, DEPTH + 8),
		"walls": [Rect2(roof_x, -DEPTH - 8, half - roof_x + 12, 14), Rect2(half, -DEPTH - 8, 12, DEPTH + 8)],
		"front": [PackedVector2Array([Vector2(half + 16, 16), Vector2(half + 16, -112), Vector2(half + 86, -112),
			Vector2(half + 118, -64), Vector2(half + 140, -56), Vector2(half + 140, 16)])],
		"reach": Rect2(-half - 60, -DEPTH - 200, IN_W + 260, DEPTH + 230),
		"ride": 70.0,
		"wheels": [[Vector2(-half + 40, 48), 30.0], [Vector2(half - 30, 48), 30.0], [Vector2(half + 100, 48), 30.0]],
	}


func _draw_back(n: Node2D):
	var half = IN_W * 0.5
	n.draw_rect(Rect2(-half, -DEPTH, IN_W, DEPTH), Color("#245A3C"))  # inside, behind cargo


func _draw_front(n: Node2D):
	var half = IN_W * 0.5
	var green = Color("#2EAE6B")
	var dark = Color("#1E8350")
	var roof_x = -half + OPEN_W
	# chassis
	n.draw_rect(Rect2(-half - 14, 0, IN_W + 170, 18), NAVY)
	# container sides (near side is a low lip so cargo inside stays visible)
	n.draw_rect(Rect2(-half - 12, -DEPTH - 8, 12, DEPTH + 8), dark)
	n.draw_rect(Rect2(half, -DEPTH - 8, 12, DEPTH + 8), dark)
	n.draw_rect(Rect2(-half, -46, IN_W, 46), green)
	n.draw_rect(Rect2(-half, -46, IN_W, 6), green.lightened(0.25))
	for x in [-half + 45, 0.0, half - 45]:
		n.draw_rect(Rect2(x - 4, -46, 8, 46), dark)
	# roof over the front part, hopper lip at the opening
	n.draw_rect(Rect2(roof_x, -DEPTH - 8, half - roof_x + 12, 14), NAVY)
	n.draw_rect(Rect2(roof_x + 2, -DEPTH - 6, half - roof_x + 8, 10), green)
	n.draw_rect(Rect2(-half - 16, -DEPTH - 14, 20, 10), Color("#FFD34E"))
	n.draw_rect(Rect2(roof_x - 4, -DEPTH - 14, 20, 10), Color("#FFD34E"))
	# cab
	var cab = PackedVector2Array([Vector2(half + 16, 16), Vector2(half + 16, -112), Vector2(half + 86, -112),
		Vector2(half + 118, -64), Vector2(half + 140, -56), Vector2(half + 140, 16)])
	n.draw_colored_polygon(cab, green)
	n.draw_rect(Rect2(half + 30, -100, 40, 32), Color("#BFE7F7"))
	n.draw_colored_polygon(PackedVector2Array([Vector2(half + 78, -100), Vector2(half + 90, -100),
		Vector2(half + 112, -66), Vector2(half + 78, -66)]), Color("#BFE7F7"))
	n.draw_rect(Rect2(half + 16, -30, 124, 8), Color(1, 1, 1, 0.85))
	n.draw_rect(Rect2(half + 128, -44, 12, 12), Color("#FFE27A"))
