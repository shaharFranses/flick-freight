extends VehicleBase
## V3: garbage truck. A deep container with a small hopper opening on top at the rear; the
## rest of the top is roofed. Cargo has to drop in on a steep arc, like a basketball shot.

const IN_W := 260.0  # inside width: 4 boxes side by side, 2 high
const DEPTH := 184.0  # 3 boxes high
const OPEN_W := 180.0  # hopper opening, from the rear wall


func _define(_cfg: Dictionary) -> Dictionary:
	var half = IN_W * 0.5
	var roof_x = -half + OPEN_W
	return {
		"zone": Rect2(-half + 2, -DEPTH, IN_W - 4, DEPTH),
		"floor_w": IN_W,
		"aim_x": [-half, roof_x],  # the bot aims into the opening, not under the roof
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
	# inside of the container, behind the cargo
	ArtDraw.bed_wall(n, Rect2(-half, -DEPTH, IN_W, DEPTH), 3, false)


func _draw_front(n: Node2D):
	var half = IN_W * 0.5
	var col: Array = ArtPalette.VEHICLE.garbage
	var roof_x = -half + OPEN_W
	# open cutaway: the near side is left off so the cargo inside stays readable
	ArtDraw.panel(n, Rect2(-half - 12, 0, IN_W + 28, 18), col, ArtDraw.PROP, 4.0, 5.0)
	ArtDraw.panel(n, Rect2(-half - 12, -DEPTH - 8, 12, DEPTH + 12), col, 3.0, 5.0, 0.0)
	ArtDraw.panel(n, Rect2(half, -DEPTH - 8, 12, DEPTH + 12), col, 3.0, 5.0, 0.0)
	# roof over the front part, amber lips at the two edges of the hopper opening
	ArtDraw.panel(n, Rect2(roof_x, -DEPTH - 8, half - roof_x + 12, 14), col, 3.0, 3.0, 0.0)
	ArtDraw.ink_rect(n, Rect2(-half - 16, -DEPTH - 16, 22, 11), ArtPalette.AMBER, 2.6)
	ArtDraw.ink_rect(n, Rect2(roof_x - 6, -DEPTH - 16, 22, 11), ArtPalette.AMBER, 2.6)
	ArtDraw.cab(n, shape.front[0], col)
