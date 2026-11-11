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
	# catch from 14 px above the belt: the bot keeps spinning cargo a corner radius away from
	# the belt's body (sim_shapes), so it has to land before that margin turns it away
	if v.y <= 0 or p.x < x0 or p.x > x1 or p.y + hh < y - 14 or p.y + hh > y + 14:
		return {}
	# drop-off just past the end, clear of the margin the bot keeps around the belt's body
	var end_x = x1 + hh * 1.5 if speed > 0 else x0 - hh * 1.5
	var frames = int(abs(end_x - p.x) / abs(speed) * 60.0) + 1
	return {"p": Vector2(end_x, y - hh), "v": Vector2(speed, 0), "frames": frames}


func _draw():
	var f = game.frame
	# legs
	for lx in [x0 + 20, (x0 + x1) * 0.5, x1 - 20]:
		ArtDraw.ink_rect(self, Rect2(lx - 7, y + T - 2, 14, Game.ROAD_Y - y - T + 2), ArtPalette.STEEL_LIGHT, 3.0)
	var r = Rect2(x0, y, x1 - x0, T)
	ArtDraw.ink_rect(self, r.grow(3), ArtPalette.BELT, 3.0)
	# moving belt stripes show the direction and speed
	var off = fposmod(f * speed / 60.0, 30.0)
	var sx = x0 + off - 30.0
	while sx < x1:
		if sx > x0:
			draw_line(Vector2(sx, y + 4), Vector2(min(sx + 12, x1), y + 4), ArtPalette.AMBER, 4.0)
		sx += 30.0
	for ex in [x0, x1]:
		ArtDraw.ink_circle(self, Vector2(ex, y + T * 0.5), T * 0.5 + 3, ArtPalette.CHROME, 3.0)
		draw_circle(Vector2(ex, y + T * 0.5), 3, ArtPalette.INK)
	# arrow
	var ax = (x0 + x1) * 0.5
	var d = sign(speed)
	draw_colored_polygon(PackedVector2Array([Vector2(ax + 14 * d, y + T * 0.5 + 2), Vector2(ax - 6 * d, y + 7),
		Vector2(ax - 6 * d, y + T - 3)]), ArtPalette.GOLD)
