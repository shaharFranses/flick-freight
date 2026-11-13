extends Mover
## M23: conveyor belt. Cargo that lands on it is carried at a fixed speed toward one end
## (toward the vehicle, or away from it) and drops off there.
## cfg: x0, x1 (belt ends), y (belt top), speed (px/s, + = to the right)
##      hang (optional, y): the belt hangs on rods from a ceiling at that height instead of
##      standing on legs, so vehicles can pass underneath it
##      tilt (optional, deg): the belt is a ramp, hinged at (x0, y), its far end raised by this
##      angle. tilt_swing (deg) / tilt_period (frames): the ramp rocks up and down around
##      `tilt` on the level clock, so cargo leaves its top end at a different height each time

var belt: StaticBody2D  # flat belt, or an AnimatableBody2D for a ramp
var x0 := 400.0
var x1 := 700.0
var y := 420.0
var speed := 140.0
var ramp := false
var tilt := 0.0
var tilt_swing := 0.0
var tilt_per := 300
const T := 20.0  # belt thickness


func _build():
	x0 = cfg.get("x0", 400.0)
	x1 = cfg.get("x1", 700.0)
	y = cfg.get("y", 420.0)
	speed = cfg.get("speed", 140.0)
	ramp = cfg.has("tilt")
	if ramp:
		tilt = deg_to_rad(cfg.get("tilt", 0.0))
		tilt_swing = deg_to_rad(cfg.get("tilt_swing", 0.0))
		tilt_per = int(cfg.get("tilt_period", 300))
		# a moving body, so cargo on it is carried along as the ramp rocks; the belt's own
		# speed is added on top (constant_linear_velocity, set every frame in pose_at)
		belt = make_body("belt", [Rect2(0, 0, x1 - x0, T)], 0.0, 1.0)
		belt.physics_material_override.rough = true
		return
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
	# a flat belt never changes when to throw; a rocking ramp does
	return tilt_per if ramp and tilt_swing != 0.0 else 0


## Ramp angle at frame f (radians, + = far end up).
func _tilt(f: int) -> float:
	return tilt + tilt_swing * sine(f, tilt_per)


## Belt space -> world at frame f: x runs along the belt from the hinge, y points into it.
func _xf(f: int) -> Transform2D:
	return Transform2D(-_tilt(f) if ramp else 0.0, Vector2(x0, y))


func pose_at(f: int):
	if not ramp:
		return
	var t = _xf(f)
	belt.position = t.origin
	belt.rotation = t.get_rotation()
	belt.constant_linear_velocity = t.x * speed


func _quad(t: Transform2D, r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([t * r.position, t * Vector2(r.end.x, r.position.y), t * r.end, t * Vector2(r.position.x, r.end.y)])


func sim_shapes(f: int) -> Array:
	# the belt's underside and ends block; landing on top is handled by sim_catch
	if ramp:
		return [_quad(_xf(f), Rect2(0, 6, x1 - x0, T - 6))]
	return [Rect2(x0, y + 6, x1 - x0, T - 6)]


## Bot: cargo of half height `hh` at p (falling, velocity v) that touches the belt top rides
## to the end and drops off. Returns {p, v, frames} to continue the flight from there, or {}.
func sim_catch(p: Vector2, v: Vector2, hh: float, f: int) -> Dictionary:
	if ramp:
		var t = _xf(f)
		var l = t.affine_inverse() * p
		var len = x1 - x0
		if v.dot(t.y) <= 0 or l.x < 0 or l.x > len or l.y + hh < -14 or l.y + hh > 14:
			return {}
		var ride = int((len - l.x) / abs(speed) * 60.0) + 1
		var t2 = _xf(f + ride)
		return {"p": t2 * Vector2(len + hh * 1.5, -hh), "v": t2.x * speed, "frames": ride}
	# catch from 14 px above the belt: the bot keeps spinning cargo a corner radius away from
	# the belt's body (sim_shapes), so it has to land before that margin turns it away
	if v.y <= 0 or p.x < x0 or p.x > x1 or p.y + hh < y - 14 or p.y + hh > y + 14:
		return {}
	# drop-off just past the end, clear of the margin the bot keeps around the belt's body
	var end_x = x1 + hh * 1.5 if speed > 0 else x0 - hh * 1.5
	var frames = int(abs(end_x - p.x) / abs(speed) * 60.0) + 1
	return {"p": Vector2(end_x, y - hh), "v": Vector2(speed, 0), "frames": frames}


func _draw():
	var f = game.frame + (phase if ramp else 0)
	var t = _xf(f)
	var len = x1 - x0
	if ramp:
		# hinge post at the low end, and a piston that pushes the ramp up and down
		ArtDraw.ink_rect(self, Rect2(x0 - 9, y, 18, Game.ROAD_Y - y), ArtPalette.STEEL_LIGHT, 3.0)
		var foot = Vector2(x0 + len * 0.45, Game.ROAD_Y)
		var head = t * Vector2(len * 0.6, T)
		draw_line(foot, head, ArtPalette.INK, 16.0)
		draw_line(foot, head, ArtPalette.STEEL_LIGHT, 10.0)
		draw_line(foot.lerp(head, 0.45), head, ArtPalette.CHROME, 5.0)
	else:
		# legs down to the road, or rods up to the ceiling it hangs from
		for lx in [x0 + 20, (x0 + x1) * 0.5, x1 - 20]:
			if cfg.has("hang"):
				var top: float = cfg.hang
				ArtDraw.ink_rect(self, Rect2(lx - 4, top, 8, y - top + 2), ArtPalette.STEEL_LIGHT, 3.0)
			else:
				ArtDraw.ink_rect(self, Rect2(lx - 7, y + T - 2, 14, Game.ROAD_Y - y - T + 2), ArtPalette.STEEL_LIGHT, 3.0)
	# everything below is drawn in belt space, so a ramp tilts with its body
	draw_set_transform_matrix(t)
	ArtDraw.ink_rect(self, Rect2(0, 0, len, T).grow(3), ArtPalette.BELT, 3.0)
	# moving belt stripes show the direction and speed
	var off = fposmod(f * speed / 60.0, 30.0)
	var sx = off - 30.0
	while sx < len:
		if sx > 0:
			draw_line(Vector2(sx, 4), Vector2(min(sx + 12, len), 4), ArtPalette.AMBER, 4.0)
		sx += 30.0
	for ex in [0.0, len]:
		ArtDraw.ink_circle(self, Vector2(ex, T * 0.5), T * 0.5 + 3, ArtPalette.CHROME, 3.0)
		draw_circle(Vector2(ex, T * 0.5), 3, ArtPalette.INK)
	# arrow
	var ax = len * 0.5
	var d = sign(speed)
	draw_colored_polygon(PackedVector2Array([Vector2(ax + 14 * d, T * 0.5 + 2), Vector2(ax - 6 * d, 7),
		Vector2(ax - 6 * d, T - 3)]), ArtPalette.GOLD)
	draw_set_transform_matrix(Transform2D.IDENTITY)
