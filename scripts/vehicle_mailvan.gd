extends VehicleBase
## V4: mail van with a narrow slot in its back door. Only flat, precise throws get a parcel
## through; it lands on the floor inside (drawn as a cutaway so you can see the sorted mail).
## Boxes don't fit the slot: they're for the other vehicles.

const IN_W := 200.0  # inside, floor length
const IN_H := 110.0  # inside, floor to roof
const SLOT_LO := 22.0  # slot bottom above the floor
const SLOT_H := 60.0
const T := 8.0  # wall thickness


func _define(_cfg: Dictionary) -> Dictionary:
	var half = IN_W * 0.5
	return {
		"zone": Rect2(-half + 2, -IN_H + 2, IN_W - 4, IN_H - 2),
		"floor_w": IN_W,
		"floor": Rect2(-half - T, 0, IN_W + 2 * T, 14),
		"rear": Rect2(-half - T, -SLOT_LO, T, SLOT_LO),  # below the slot
		"walls": [Rect2(-half - T, -IN_H, T, IN_H - SLOT_LO - SLOT_H),  # above the slot
			Rect2(-half - T, -IN_H - T, IN_W + 2 * T, T),  # roof
			Rect2(half, -IN_H, T, IN_H)],  # bulkhead
		"front": [PackedVector2Array([Vector2(half + T, 14), Vector2(half + T, -IN_H + 10), Vector2(half + 60, -IN_H + 10),
			Vector2(half + 92, -40), Vector2(half + 96, 14)])],
		"reach": Rect2(-half - 40, -IN_H - 60, IN_W + 180, IN_H + 100),
		"floor_friction": 0.04,  # rollers: whatever gets in slides to the far end
		"ride": 64.0,
		"wheels": [[Vector2(-half + 40, 38), 26.0], [Vector2(half + 50, 38), 26.0]],
	}


func sim_profile() -> Dictionary:
	var pr = super.sim_profile()
	pr["solids"] = [shape.rear] + shape.walls + [VehicleBase._poly_rect(shape.front[0])]
	pr["any_spot"] = true  # the rollers carry it to the far end: getting in is what counts
	return pr


func _draw_back(n: Node2D):
	var half = IN_W * 0.5
	# cutaway: the load space behind the cargo, with two shelves
	ArtDraw.bed_wall(n, Rect2(-half, -IN_H, IN_W, IN_H), 2, false)
	for y in [-IN_H * 0.66, -IN_H * 0.33]:
		n.draw_rect(Rect2(-half + 70, y - 2, IN_W - 76, 4), ArtPalette.BED_RAIL)


func _draw_front(n: Node2D):
	var half = IN_W * 0.5
	var col: Array = ArtPalette.VEHICLE.mailvan
	# body shell: only the walls, roof and floor; the near side is cut away
	ArtDraw.ink_rect(n, Rect2(-half - T, 0, IN_W + 2 * T + 4, 16), col[0], 3.0)
	n.draw_rect(Rect2(-half - T + 3, 6, IN_W + 2 * T - 2, 5), ArtPalette.CORAL)
	for r in [shape.rear] + shape.walls:
		ArtDraw.ink_rect(n, r, col[0], 2.0)
	# slot frame: amber edges so it reads at a glance
	ArtDraw.ink_rect(n, Rect2(-half - T - 4, -SLOT_LO - SLOT_H - 6, T + 8, 8), ArtPalette.AMBER, 2.0)
	ArtDraw.ink_rect(n, Rect2(-half - T - 4, -SLOT_LO - 2, T + 8, 8), ArtPalette.AMBER, 2.0)
	ArtDraw.cab(n, shape.front[0], col, ArtPalette.CORAL)
	# envelope sign on the roof
	var e = Rect2(-25, -IN_H - T - 26, 50, 27)
	ArtDraw.ink_rect(n, e, ArtPalette.AMBER, 3.0)
	n.draw_line(e.position + Vector2(3, 3), Vector2(0, e.position.y + 15), NAVY, 2.5)
	n.draw_line(Vector2(e.end.x - 3, e.position.y + 3), Vector2(0, e.position.y + 15), NAVY, 2.5)
