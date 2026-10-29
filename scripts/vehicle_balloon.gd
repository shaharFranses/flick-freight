extends VehicleBase
## V9: hot-air balloon basket. It slowly rises and sinks and sways, all from the level clock
## (like the helicopter), so it's a vertical-timing target. The envelope above is solid:
## lob over it and the cargo bounces off, so throws come in under it from the side.
##
## cfg: x, y          basket floor at the middle of its rise
##      rise          vertical amplitude (px), rise_period (frames)
##      sway          sideways amplitude (px), sway_period (frames); the basket tilts with it
##      phase         clock offset (frames)

const BASKET_W := 220.0
const BASKET_H := 52.0
const ROPES := 120.0  # basket rim to the bottom of the envelope
const ENV_R := 90.0
const ARRIVE_FROM := Vector2(420, 320)

var centre := Vector2(900, 380)
var rise := 50.0
var rise_period := 300
var sway := 0.0
var sway_period := 420
var phase := 0
var _off := Vector2.ZERO
var _lift := 0.0
var _flame := 0


func _init():
	lift_off_on_win = true


func _define(cfg: Dictionary) -> Dictionary:
	centre = Vector2(cfg.x, cfg.get("y", 380.0))
	rise = cfg.get("rise", rise)
	rise_period = int(cfg.get("rise_period", rise_period))
	sway = cfg.get("sway", sway)
	sway_period = int(cfg.get("sway_period", sway_period))
	phase = int(cfg.get("phase", 0))
	amp = 0.0
	var half = BASKET_W * 0.5
	return {
		"zone": Rect2(-half + 2, -240, BASKET_W - 4, 240),
		"floor_w": BASKET_W,
		"floor": Rect2(-half - 8, 0, BASKET_W + 16, 12),
		"rear": Rect2(-half - 8, -BASKET_H, 8, BASKET_H),
		"walls": [Rect2(half, -BASKET_H, 8, BASKET_H)],
		"front": [],
		"reach": Rect2(-half - 40, -280, BASKET_W + 80, 320),
		"ride": 0.0,
		"wheels": [],
	}


func _env_centre() -> Vector2:
	return Vector2(0, -BASKET_H - ROPES - ENV_R)


func _build_bodies():
	_body("truck_floor", [shape.floor], 1.0, 0.0)
	_body("truck_wall", [shape.rear] + shape.walls, 0.8, 0.05)
	# the envelope: a solid circle riding with the basket
	var env = AnimatableBody2D.new()
	env.sync_to_physics = false
	env.add_to_group("block")
	var pm = PhysicsMaterial.new()
	pm.bounce = 0.3
	pm.friction = 0.4
	env.physics_material_override = pm
	var cs = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = ENV_R
	cs.shape = c
	cs.position = _env_centre()
	env.add_child(cs)
	add_child(env)


# ---------------------------------------------------------------- the clock
func _clock() -> float:
	var g = get_parent()
	return float(g.frame + phase) if g is Game else 0.0


func _pos(f: float) -> Vector2:
	var p = centre + Vector2(0, rise * sin(TAU * f / rise_period))
	if sway > 0:
		p.x += sway * sin(TAU * f / sway_period)
	return p


func _tilt(f: float) -> float:
	return deg_to_rad(4.0) * sin(TAU * f / sway_period) if sway > 0 else 0.0


func period_frames() -> int:
	return Game._lcm(rise_period, sway_period) if sway > 0 else rise_period


# ---------------------------------------------------------------- motion
func arrive():
	state = "arriving"
	_anim_t = 0.0
	_off = ARRIVE_FROM
	_place(_clock())
	reset_physics_interpolation()
	Sfx.play("whoosh", -12.0, 0.6)


## Win showcase / full: burner on, the balloon climbs away.
func leave():
	glue_all()
	state = "leaving"
	_lift = 0.0
	Sfx.play("whoosh", -4.0, 0.5)


func _physics_process(delta: float):
	var f = _clock()
	match state:
		"arriving":
			_anim_t = min(1.0, _anim_t + delta / 1.6)
			_off = ARRIVE_FROM * pow(1.0 - _anim_t, 3)
			if _anim_t >= 1.0:
				_off = Vector2.ZERO
				state = "parked"
				arrived.emit()
		"leaving":
			_lift += delta
			_off = Vector2(40.0 * _lift, -260.0 * _lift * _lift)
			if _lift > 2.0:
				state = "away"
				for l in loads:
					if is_instance_valid(l.cargo):
						l.cargo.queue_free()
				loads.clear()
				departed.emit()
				queue_free()
				return
	var before = global_position
	_place(f)
	velocity_x = (global_position.x - before.x) / delta if delta > 0 else 0.0
	for l in loads:
		var c: Cargo = l.cargo
		if is_instance_valid(c) and c.freeze:
			c.global_position = to_global(l.local)
			c.rotation = rotation + l.lrot
	_flame += 1
	front_layer.queue_redraw()


func _place(f: float):
	position = _pos(f) + _off
	rotation = _tilt(f)


func point_velocity(_p: Vector2) -> Vector2:
	var f = _clock()
	return (_pos(f + 0.5) - _pos(f - 0.5)) * 60.0


func glue_all():
	for l in loads:
		var c: Cargo = l.cargo
		if not is_instance_valid(c) or c.freeze:
			continue
		c.freeze = true
		c.linear_velocity = Vector2.ZERO
		c.angular_velocity = 0.0
		l.local = to_local(c.global_position)
		l.lrot = c.rotation - rotation


# ---------------------------------------------------------------- QA bot
func sim_profile() -> Dictionary:
	var pr = super.sim_profile()
	pr["pack_front"] = true  # room for one row only: the bot fills it from the far wall
	return pr


func predict_pose(dt: float) -> Array:
	var f = _clock() + dt * 60.0
	return [_pos(f), _tilt(f)]


func predict_vx(dt: float) -> float:
	var f = _clock() + dt * 60.0
	return (_pos(f + 0.5).x - _pos(f - 0.5).x) * 60.0


## The envelope `dt` s from now, as a circle: Vector3(x, y, radius).
func sim_obstacles(dt: float) -> Array:
	var f = _clock() + dt * 60.0
	var c = _pos(f) + _env_centre().rotated(_tilt(f))
	return [Vector3(c.x, c.y, ENV_R)]


func sim_obstacles_lowest() -> float:
	return centre.y + rise - BASKET_H - ROPES + 6.0


# ---------------------------------------------------------------- drawing
func _draw_back(n: Node2D):
	# the wicker is behind the cargo so loads stay visible; only the rim is in front
	var half = BASKET_W * 0.5
	var rim = -BASKET_H
	n.draw_rect(Rect2(-half - 8, rim, BASKET_W + 16, BASKET_H + 12).grow(2), NAVY)
	n.draw_rect(Rect2(-half - 8, rim, BASKET_W + 16, BASKET_H + 12), Color("#C98E4A"))
	for i in 4:
		n.draw_line(Vector2(-half - 8, rim + 8 + i * 14), Vector2(half + 8, rim + 8 + i * 14), Color("#A26B33"), 3.0)


func _draw_front(n: Node2D):
	var half = BASKET_W * 0.5
	var ec = _env_centre()
	var rim = -BASKET_H
	# ropes up to the envelope
	for x in [-half + 4, half - 4]:
		n.draw_line(Vector2(x, rim), Vector2(sign(x) * ENV_R * 0.45, ec.y + ENV_R * 0.9), NAVY, 3.0)
	# burner + flame
	n.draw_rect(Rect2(-12, ec.y + ENV_R + 6, 24, 16), NAVY)
	if _flame % 6 < 3:
		n.draw_colored_polygon(PackedVector2Array([Vector2(-8, ec.y + ENV_R + 6), Vector2(0, ec.y + ENV_R - 18), Vector2(8, ec.y + ENV_R + 6)]), Color("#FFB347"))
	# envelope: striped
	n.draw_circle(ec, ENV_R + 3, NAVY)
	n.draw_circle(ec, ENV_R, Color("#F26B4E"))
	for k in [-1.0, 1.0]:
		var pts = PackedVector2Array()
		for i in 13:
			var a = -PI * 0.5 + PI * i / 12.0
			pts.append(ec + Vector2(cos(a) * ENV_R * 0.45 * k, sin(a) * ENV_R))
		n.draw_polyline(pts, Color("#FFD34E"), 10.0)
	n.draw_colored_polygon(PackedVector2Array([ec + Vector2(-ENV_R * 0.62, ENV_R * 0.62), ec + Vector2(ENV_R * 0.62, ENV_R * 0.62),
		ec + Vector2(ENV_R * 0.3, ENV_R + 4), ec + Vector2(-ENV_R * 0.3, ENV_R + 4)]), Color("#F26B4E"))
	# basket sides and rim
	for x in [-half - 8, half]:
		n.draw_rect(Rect2(x, rim, 8, BASKET_H + 12), Color("#A26B33"))
	n.draw_rect(Rect2(-half - 8, 0, BASKET_W + 16, 12), Color("#A26B33"))
	n.draw_rect(Rect2(-half - 10, rim - 4, BASKET_W + 20, 8), Color("#8A5A32"))
