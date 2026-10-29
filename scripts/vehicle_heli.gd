extends VehicleBase
## V8: helicopter with a net hanging on a cable (Plan 2 §3.3). The helicopter hovers on a
## scripted path (bob, slow drift) and the net swings on a scripted pendulum: everything is a
## pure function of the level clock, so cargo in the net never changes the swing and the bot
## can look ahead. The net is the vehicle (origin = middle of the net floor); the helicopter
## body is a solid that cargo bounces off. Win = lift-off with rotor noise and a camera shake.
##
## cfg: x, y          hover point of the hook (where the cable starts)
##      cable         cable length, hook to net floor (px)
##      swing         pendulum amplitude (deg); swing_period (frames) defaults to the cable's
##                    natural period, so cargo in the net rides along calmly as in a real one
##      bob           hover bob (px, vertical), bob_period (frames)
##      drift         slow sideways drift (px), drift_period (frames)
##      phase         clock offset (frames), e.g. two helicopters out of step
## The exported values are the defaults, for tuning the feel in the editor.

@export var cable := 300.0
@export var swing_deg := 12.0
@export var swing_period := 0  # 0 = the natural period of the cable
@export var bob := 0.0
@export var bob_period := 240
@export var drift := 0.0
@export var drift_period := 600
@export var net_w := 250.0
@export var net_h := 58.0

const HOOK := 44.0  # hook below the rotor hub
const ARRIVE_FROM := Vector2(560, -460)

var hover := Vector2(900, 120)
var phase := 0
var heli: AnimatableBody2D  # fuselage (solid)
var heli_vis: Node2D
var _off := Vector2.ZERO  # arrive / lift-off offset
var _lift := 0.0
var _vel := Vector2.ZERO  # hook velocity
var _omega := 0.0  # net angular velocity (rad/s)
var _blade := 0


func _init():
	lift_off_on_win = true


func _define(cfg: Dictionary) -> Dictionary:
	hover = Vector2(cfg.x, cfg.get("y", 120.0))
	cable = cfg.get("cable", cable)
	swing_deg = cfg.get("swing", swing_deg)
	swing_period = int(cfg.get("swing_period", swing_period))
	if swing_period <= 0:
		# pendulum to the middle of the cargo (~25 px above the net floor), g = Game.GRAVITY
		swing_period = int(round(60.0 * TAU * sqrt((cable - 25.0) / Game.GRAVITY)))
	bob = cfg.get("bob", bob)
	bob_period = int(cfg.get("bob_period", bob_period))
	drift = cfg.get("drift", drift)
	drift_period = int(cfg.get("drift_period", drift_period))
	phase = int(cfg.get("phase", 0))
	amp = 0.0
	var half = net_w * 0.5
	return {
		"zone": Rect2(-half + 2, -260, net_w - 4, 260),
		"floor_w": net_w,
		"floor": Rect2(-half - 6, 0, net_w + 12, 10),
		"rear": Rect2(-half - 6, -net_h, 6, net_h),
		"walls": [Rect2(half, -net_h, 6, net_h)],
		"front": [],
		"reach": Rect2(-half - 40, -300, net_w + 80, 340),
		"ride": 0.0,
		"wheels": [],
	}


func _build_bodies():
	# soft net: no bounce, grippy
	_body("truck_floor", [shape.floor], 1.0, 0.0)
	_body("truck_wall", [shape.rear] + shape.walls, 0.9, 0.0)
	heli = AnimatableBody2D.new()
	heli.sync_to_physics = false
	heli.top_level = true
	heli.add_to_group("block")
	for poly in _fuselage():
		var cs = CollisionShape2D.new()
		var cp = ConvexPolygonShape2D.new()
		cp.points = poly
		cs.shape = cp
		heli.add_child(cs)
	add_child(heli)


func _build_visuals():
	super._build_visuals()
	heli_vis = Node2D.new()
	heli_vis.top_level = true
	heli_vis.z_index = 3
	heli_vis.draw.connect(_draw_heli)
	add_child(heli_vis)


## Fuselage polygons around the rotor hub (local to the hub).
func _fuselage() -> Array:
	return [PackedVector2Array([Vector2(-54, 4), Vector2(-40, -18), Vector2(40, -18), Vector2(62, 2), Vector2(56, 30), Vector2(-46, 30)]),
		PackedVector2Array([Vector2(-130, -6), Vector2(-50, -6), Vector2(-50, 12), Vector2(-130, 4)])]


# ---------------------------------------------------------------- the clock
func _clock() -> float:
	var g = get_parent()
	return float(g.frame + phase) if g is Game else 0.0


func _hook(f: float) -> Vector2:
	var p = hover
	if drift > 0:
		p.x += drift * sin(TAU * f / drift_period)
	if bob > 0:
		p.y += bob * sin(TAU * f / bob_period)
	return p + Vector2(0, HOOK)


func _theta(f: float) -> float:
	return deg_to_rad(swing_deg) * sin(TAU * f / swing_period)


func _net(f: float) -> Vector2:
	var th = _theta(f)
	return _hook(f) + cable * Vector2(sin(th), cos(th))


func period_frames() -> int:
	var p = swing_period
	if bob > 0:
		p = Game._lcm(p, bob_period)
	if drift > 0:
		p = Game._lcm(p, drift_period)
	return p


# ---------------------------------------------------------------- motion
func arrive():
	state = "arriving"
	_anim_t = 0.0
	_place(_clock(), ARRIVE_FROM)
	reset_physics_interpolation()
	Sfx.play("rotor", -8.0, 1.0)


## Lift-off: strap the cargo in and climb away (the showcase when a level is won).
func leave():
	glue_all()
	state = "leaving"
	_lift = 0.0
	Sfx.play("rotor", 0.0, 1.1)
	var g = get_parent()
	if g is Game:
		g.shake(9.0, 0.6)


func _physics_process(delta: float):
	var f = _clock()
	match state:
		"arriving":
			_anim_t = min(1.0, _anim_t + delta / 1.4)
			_off = ARRIVE_FROM * pow(1.0 - _anim_t, 3)
			if _anim_t >= 1.0:
				_off = Vector2.ZERO
				state = "parked"
				arrived.emit()
		"leaving":
			_lift += delta
			_off = Vector2(90.0 * _lift * _lift, -380.0 * _lift * _lift)
			if _lift > 1.8:
				state = "away"
				for l in loads:
					if is_instance_valid(l.cargo):
						l.cargo.queue_free()
				loads.clear()
				departed.emit()
				queue_free()
				return
	var before_hook = _hook(f - 1) + _off
	var before_th = _theta(f - 1)
	_place(f, _off)
	_vel = (_hook(f) + _off - before_hook) / delta if delta > 0 else Vector2.ZERO
	_omega = -(_theta(f) - before_th) / delta if delta > 0 else 0.0
	velocity_x = point_velocity(global_position).x
	for l in loads:
		var c: Cargo = l.cargo
		if is_instance_valid(c) and c.freeze:
			c.global_position = to_global(l.local)
			c.rotation = rotation + l.lrot
	_blade += 1
	heli_vis.queue_redraw()
	queue_redraw()


func _place(f: float, off: Vector2):
	var th = _theta(f)
	var hook = _hook(f) + off
	position = hook + cable * Vector2(sin(th), cos(th))
	rotation = -th
	heli.global_position = hook - Vector2(0, HOOK)
	heli.global_rotation = 0.0
	heli_vis.global_position = heli.global_position
	heli_vis.global_rotation = 0.0


func point_velocity(p: Vector2) -> Vector2:
	var r = p - (_hook(_clock()) + _off)
	return _vel + _omega * Vector2(-r.y, r.x)


# ---------------------------------------------------------------- loads (the net rotates)
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


func top_center() -> Vector2:
	return to_global(Vector2(0, -net_h - 30))


# ---------------------------------------------------------------- QA bot
func sim_profile() -> Dictionary:
	var pr = super.sim_profile()
	pr["pack_front"] = true  # room for one row only: the bot fills it from the far wall
	return pr


func predict_pose(dt: float) -> Array:
	var f = _clock() + dt * 60.0
	return [_net(f), -_theta(f)]


func predict_vx(dt: float) -> float:
	var f = _clock() + dt * 60.0
	return (_net(f + 0.5).x - _net(f - 0.5).x) * 60.0


## Solid parts that aren't the net, `dt` s from now: [Rect2] in world space.
func sim_obstacles(dt: float) -> Array:
	var hub = _hook(_clock() + dt * 60.0) - Vector2(0, HOOK)
	return [Rect2(hub + Vector2(-130, -18), Vector2(192, 48))]


func sim_obstacles_lowest() -> float:
	return hover.y + bob + 30.0


# ---------------------------------------------------------------- drawing
func _draw():
	# cable from the hook to the net's corners (in the net's own space)
	var hook_l = to_local(heli.global_position + Vector2(0, HOOK))
	var half = net_w * 0.5
	draw_line(hook_l, Vector2(-half, -net_h), NAVY, 3.0)
	draw_line(hook_l, Vector2(half, -net_h), NAVY, 3.0)
	draw_circle(hook_l, 6, NAVY)


func _draw_back(n: Node2D):
	var half = net_w * 0.5
	n.draw_rect(Rect2(-half, -net_h, net_w, net_h), Color(0.106, 0.165, 0.255, 0.25))


func _draw_front(n: Node2D):
	var half = net_w * 0.5
	var rope = Color("#E8D9B0")
	n.draw_rect(Rect2(-half - 6, 0, net_w + 12, 10), NAVY)
	for x in [-half - 6, half]:
		n.draw_rect(Rect2(x, -net_h, 6, net_h), NAVY)
	# mesh
	var k = -half
	while k <= half:
		n.draw_line(Vector2(k, -net_h), Vector2(k, 2), rope, 2.0)
		k += 16.0
	for y in [-net_h + 2, -net_h * 0.5, -2.0]:
		n.draw_line(Vector2(-half, y), Vector2(half, y), rope, 2.0)
	n.draw_line(Vector2(-half - 6, -net_h), Vector2(half + 6, -net_h), Color("#F2B134"), 4.0)


func _draw_heli():
	var n = heli_vis
	var body = Color("#E4572E")
	var dark = Color("#B8401F")
	var glass = Color("#BFE7F7")
	# tail boom + tail rotor
	n.draw_colored_polygon(PackedVector2Array([Vector2(-133, -9), Vector2(-48, -9), Vector2(-48, 15), Vector2(-133, 7)]), NAVY)
	n.draw_colored_polygon(PackedVector2Array([Vector2(-130, -6), Vector2(-50, -6), Vector2(-50, 12), Vector2(-130, 4)]), dark)
	var tr = 18.0 if _blade % 4 < 2 else 6.0
	n.draw_line(Vector2(-130, -tr), Vector2(-130, tr), NAVY, 4.0)
	n.draw_circle(Vector2(-130, 0), 5, NAVY)
	# cabin
	var cab = PackedVector2Array([Vector2(-54, 4), Vector2(-40, -18), Vector2(40, -18), Vector2(62, 2), Vector2(56, 30), Vector2(-46, 30)])
	n.draw_colored_polygon(Geometry2D.offset_polygon(cab, 3)[0], NAVY)
	n.draw_colored_polygon(cab, body)
	n.draw_colored_polygon(PackedVector2Array([Vector2(12, -14), Vector2(38, -14), Vector2(56, 2), Vector2(12, 2)]), glass)
	n.draw_rect(Rect2(-30, -12, 30, 14), glass)
	n.draw_rect(Rect2(-46, 18, 102, 6), dark)
	# skids
	n.draw_line(Vector2(-40, 30), Vector2(-46, 42), NAVY, 4.0)
	n.draw_line(Vector2(36, 30), Vector2(42, 42), NAVY, 4.0)
	n.draw_line(Vector2(-60, 42), Vector2(62, 42), NAVY, 5.0)
	# mast + main rotor: two alternating frames for the blur
	n.draw_rect(Rect2(-5, -30, 10, 14), NAVY)
	if _blade % 4 < 2:
		n.draw_line(Vector2(-150, -31), Vector2(150, -31), NAVY, 6.0)
		n.draw_line(Vector2(-150, -31), Vector2(150, -31), Color(0.9, 0.93, 1.0, 0.55), 2.0)
	else:
		n.draw_line(Vector2(-90, -33), Vector2(90, -29), NAVY, 6.0)
		n.draw_rect(Rect2(-150, -35, 300, 8), Color(0.106, 0.165, 0.255, 0.15))
	n.draw_circle(Vector2(0, -31), 7, NAVY)
