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
	# far side of the bed, behind the cargo
	ArtDraw.bed_wall(n, Rect2(-half, -SIDE, BED, SIDE), 3, false)
	n.draw_rect(Rect2(-half, -SIDE - 4, BED, 6), ArtPalette.BED_RAIL)


func _draw_front(n: Node2D):
	var half = BED * 0.5
	var col: Array = ArtPalette.VEHICLE.pickup
	# open cutaway: in front of the cargo only the tailgate post and the cab back wall
	ArtDraw.panel(n, Rect2(-half - 8, 0, BED + 24, 16), col, ArtDraw.PROP, 4.0, 4.0)
	ArtDraw.ink_rect(n, Rect2(-half - 8, -SIDE, 8, SIDE + 6), col[0], 2.5)
	ArtDraw.ink_rect(n, Rect2(half, -80, 12, 86), col[1], 2.5)
	ArtDraw.cab(n, shape.front[0], col)
	ArtDraw.ink_rect(n, Rect2(-half - 14, 2, 8, 10), ArtPalette.CORAL, 2.0)  # tail light
