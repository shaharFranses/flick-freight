extends Mover
## M23: conveyor belt on legs. Cargo that lands on it is carried at a fixed speed toward one
## end (toward the vehicle, or away from it) and drops off there.
## cfg: x0, x1 (belt ends), y (belt top), speed (px/s, + = to the right)

var belt: StaticBody2D
var x0 := 400.0
var x1 := 700.0
var y := 420.0
var speed := 140.0
const T := 20.0  # belt thickness


func _build():
	x0 = cfg.get("x0", 400.0)
	x1 = cfg.get("x1", 700.0)
	y = cfg.get("y", 420.0)
	speed = cfg.get("speed", 140.0)
	belt = StaticBody2D.new()
	belt.add_to_group("belt")
	belt.constant_linear_velocity = Vector2(speed, 0)
	var pm = PhysicsMaterial.new()
	pm.friction = 1.0
	pm.bounce = 0.0
	belt.physics_material_override = pm
	var cs = CollisionShape2D.new()
	var rs = RectangleShape2D.new()
	rs.size = Vector2(x1 - x0, T)
	cs.shape = rs
	cs.position = Vector2((x0 + x1) * 0.5, y + T * 0.5)
	belt.add_child(cs)
	add_child(belt)


func period_frames() -> int:
	return 0  # nothing moves in a way that changes when to throw


func sim_shapes(_f: int) -> Array:
	# the belt's underside and ends block; landing on top is handled by sim_catch
	return [Rect2(x0, y + 6, x1 - x0, T - 6)]


## Bot: cargo of half height `hh` at p (falling, velocity v) that touches the belt top rides
## to the end and drops off. Returns {p, v, frames} to continue the flight from there, or {}.
func sim_catch(p: Vector2, v: Vector2, hh: float, _f: int) -> Dictionary:
	if v.y <= 0 or p.x < x0 or p.x > x1 or p.y + hh < y or p.y + hh > y + 14:
		return {}
	var end_x = x1 + hh if speed > 0 else x0 - hh
	var frames = int(abs(end_x - p.x) / abs(speed) * 60.0) + 1
	return {"p": Vector2(end_x, y - hh), "v": Vector2(speed, 0), "frames": frames}


func _draw():
	var f = game.frame
	var navy = Color("#1B2A41")
	# legs
	for lx in [x0 + 20, (x0 + x1) * 0.5, x1 - 20]:
		draw_rect(Rect2(lx - 6, y + T, 12, Game.ROAD_Y - y - T), navy)
		draw_rect(Rect2(lx - 3, y + T, 6, Game.ROAD_Y - y - T), Color("#7D8894"))
	var r = Rect2(x0, y, x1 - x0, T)
	draw_rect(r.grow(3), navy)
	draw_rect(r, Color("#3E4A5C"))
	# moving belt stripes show the direction and speed
	var off = fposmod(f * speed / 60.0, 30.0)
	var sx = x0 + off - 30.0
	while sx < x1:
		if sx > x0:
			draw_line(Vector2(sx, y + 3), Vector2(min(sx + 12, x1), y + 3), Color("#F2B134"), 3.0)
		sx += 30.0
	for ex in [x0, x1]:
		draw_circle(Vector2(ex, y + T * 0.5), T * 0.5 + 2, navy)
		draw_circle(Vector2(ex, y + T * 0.5), T * 0.5 - 2, Color("#AAB4BF"))
	# arrow
	var ax = (x0 + x1) * 0.5
	var d = sign(speed)
	draw_colored_polygon(PackedVector2Array([Vector2(ax + 14 * d, y + T * 0.5), Vector2(ax - 6 * d, y + 3),
		Vector2(ax - 6 * d, y + T - 3)]), Color("#FFD34E"))
