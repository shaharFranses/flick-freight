extends VehicleBase
## V10: food truck. Supplies go in through the serving window in its back, under a striped
## awning: not too flat (the window is high), not too steep (the awning is in the way).
## Drawn as a cutaway so you can see what's been delivered.

const IN_W := 240.0
const IN_H := 190.0
const WIN_H := 150.0  # serving window, from the counter (floor) up
const T := 8.0
const AWNING := 30.0  # how far the awning sticks out
const SILL := 16.0  # lip under the window: what's inside can't roll back out


func _define(_cfg: Dictionary) -> Dictionary:
	var half = IN_W * 0.5
	return {
		"zone": Rect2(-half + 2, -IN_H + 2, IN_W - 4, IN_H - 2),
		"floor_w": IN_W,
		"floor": Rect2(-half - T, 0, IN_W + 2 * T, 30),  # counter + the body below it
		"rear": Rect2(-half - T, -IN_H, T, IN_H - WIN_H),  # wall above the window
		"walls": [Rect2(-half - T, -IN_H - T, IN_W + 2 * T, T),  # roof
			Rect2(half, -IN_H, T, IN_H),
			PackedVector2Array([Vector2(-half - T, -WIN_H - 10), Vector2(-half - T - AWNING, -WIN_H + 2),
				Vector2(-half - T - AWNING, -WIN_H + 10), Vector2(-half - T, -WIN_H - 2)]),  # awning
			Rect2(-half - T, -SILL, T, SILL)],  # sill
		"front": [PackedVector2Array([Vector2(half + T, 30), Vector2(half + T, -70), Vector2(half + 56, -70),
			Vector2(half + 84, -20), Vector2(half + 88, 30)])],
		"reach": Rect2(-half - AWNING - 20, -IN_H - 60, IN_W + 200, IN_H + 110),
		"floor_friction": 0.04,  # rollers: whatever gets in slides to the far end
		"ride": 66.0,
		"wheels": [[Vector2(-half + 40, 40), 26.0], [Vector2(half + 46, 40), 26.0]],
	}


func sim_profile() -> Dictionary:
	var pr = super.sim_profile()
	pr["solids"] = [shape.rear, shape.walls[0], shape.walls[1], VehicleBase._poly_rect(shape.walls[2]),
		shape.walls[3], VehicleBase._poly_rect(shape.front[0])]
	pr["any_spot"] = true  # the rollers carry it to the far end: getting in is what counts
	return pr


func _draw_back(n: Node2D):
	var half = IN_W * 0.5
	n.draw_rect(Rect2(-half, -IN_H, IN_W, IN_H), Color("#3B2F2A"))
	n.draw_rect(Rect2(half - 50, -IN_H + 20, 40, 60), Color("#5A4A42"))  # fridge
	n.draw_circle(Vector2(half - 70, -30), 10, Color("#6B5A50"))


func _draw_front(n: Node2D):
	var half = IN_W * 0.5
	var body = Color("#3DDC97")
	var dark = Color("#24A872")
	n.draw_rect(shape.floor.grow(2), NAVY)
	n.draw_rect(shape.floor, body)
	n.draw_rect(Rect2(-half - T, -4, IN_W + 2 * T, 8), Color("#C9CED6"))  # counter
	for r in [shape.rear, shape.walls[0], shape.walls[1], shape.walls[3]]:
		n.draw_rect(r.grow(2), NAVY)
		n.draw_rect(r, body)
	# awning, red and white stripes
	var aw: PackedVector2Array = shape.walls[2]
	n.draw_colored_polygon(Geometry2D.offset_polygon(aw, 2)[0], NAVY)
	n.draw_colored_polygon(aw, Color.WHITE)
	for k in 3:
		var a = float(k) / 3.0
		var b = a + 1.0 / 6.0
		n.draw_colored_polygon(PackedVector2Array([aw[0].lerp(aw[1], a), aw[0].lerp(aw[1], b), aw[3].lerp(aw[2], b), aw[3].lerp(aw[2], a)]), Color("#E4572E"))
	var cab = shape.front[0]
	n.draw_colored_polygon(Geometry2D.offset_polygon(cab, 3)[0], NAVY)
	n.draw_colored_polygon(cab, body)
	n.draw_colored_polygon(PackedVector2Array([Vector2(half + 56, -62), Vector2(half + 60, -62), Vector2(half + 78, -26),
		Vector2(half + 56, -26)]), Color("#BFE7F7"))
	n.draw_rect(Rect2(-half - T, 30, IN_W + 2 * T + 88, 10), NAVY)
	n.draw_rect(Rect2(-half + 10, 8, IN_W - 20, 14), dark)
	# sign on the roof
	n.draw_rect(Rect2(-56, -IN_H - T - 34, 112, 30).grow(2), NAVY)
	n.draw_rect(Rect2(-56, -IN_H - T - 34, 112, 30), Color("#FFD34E"))
	n.draw_circle(Vector2(-30, -IN_H - T - 19), 9, Color("#E4572E"))
	n.draw_rect(Rect2(-14, -IN_H - T - 24, 56, 10), Color("#E4572E"))
