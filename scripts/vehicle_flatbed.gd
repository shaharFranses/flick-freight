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
	var col: Array = ArtPalette.VEHICLE.flatbed
	# steel deck with no sides at all, on a chassis rail
	ArtDraw.ink_rect(n, Rect2(-half - 4, 0, BED + 162, 20), ArtPalette.STEEL, ArtDraw.PROP)
	n.draw_rect(Rect2(-half, 4, BED + 2, 6), ArtPalette.DECK_PLATE)
	for x in range(int(-half) + 30, int(half), 60):
		n.draw_rect(Rect2(x - 1, 4, 2, 6), ArtPalette.BED_POST)
	ArtDraw.cab(n, shape.front[0], col)
