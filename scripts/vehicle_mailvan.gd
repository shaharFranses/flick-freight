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
	# cutaway: dark load space with shelves
	n.draw_rect(Rect2(-half, -IN_H, IN_W, IN_H), Color("#2E3A4E"))
	for y in [-IN_H * 0.66, -IN_H * 0.33]:
		n.draw_line(Vector2(-half + 70, y), Vector2(half - 6, y), Color("#46546B"), 4.0)


func _draw_front(n: Node2D):
	var half = IN_W * 0.5
	var body = Color("#F2F2EE")
	var stripe = Color("#E4572E")
	for r in [shape.rear] + shape.walls:
		n.draw_rect(r.grow(2), NAVY)
		n.draw_rect(r, body)
	n.draw_rect(Rect2(-half - T, 0, IN_W + 2 * T + 96, 16).grow(2), NAVY)
	n.draw_rect(Rect2(-half - T, 0, IN_W + 2 * T + 96, 16), body)
	n.draw_rect(Rect2(-half - T, 4, IN_W + 2 * T + 96, 6), stripe)
	# slot frame: yellow edges so it reads at a glance
	n.draw_rect(Rect2(-half - T - 3, -SLOT_LO - SLOT_H - 4, T + 6, 4), Color("#FFD34E"))
	n.draw_rect(Rect2(-half - T - 3, -SLOT_LO, T + 6, 4), Color("#FFD34E"))
	var cab = shape.front[0]
	n.draw_colored_polygon(Geometry2D.offset_polygon(cab, 3)[0], NAVY)
	n.draw_colored_polygon(cab, body)
	n.draw_colored_polygon(PackedVector2Array([Vector2(half + 60, -IN_H + 18), Vector2(half + 66, -IN_H + 18),
		Vector2(half + 86, -46), Vector2(half + 60, -46)]), Color("#BFE7F7"))
	n.draw_rect(Rect2(half + 18, -60, 34, 10), stripe)
	# envelope logo on the roof edge
	n.draw_rect(Rect2(-24, -IN_H - T - 26, 48, 22), NAVY)
	n.draw_rect(Rect2(-22, -IN_H - T - 24, 44, 18), Color("#FFD34E"))
	n.draw_line(Vector2(-22, -IN_H - T - 24), Vector2(0, -IN_H - T - 12), NAVY, 2.0)
	n.draw_line(Vector2(22, -IN_H - T - 24), Vector2(0, -IN_H - T - 12), NAVY, 2.0)
