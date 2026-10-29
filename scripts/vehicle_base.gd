class_name VehicleBase
extends CargoVehicle
## Shared behaviour for the Plan 2 vehicles (V1+): drive in, park (optionally sway on
## amp/period like the truck), carry and strap down loads, drive off. A subclass only
## describes its shape in _define() and draws itself. The original truck (V0) does not
## use this: it keeps its own code untouched.
##
## Shape, in local space (origin = middle of the load floor's top surface):
##   zone       Rect2   where settled cargo counts as loaded
##   floor_w    float   load floor width (bot: where it aims)
##   rear       Rect2   rear wall / rail (solid)
##   front      Array   solid parts at the front that count as the "cab" (landing there = miss)
##   walls      Array   other solid walls (Rect2 or polygon)
##   floor      Rect2   the load floor (solid)
##   reach      Rect2   whole vehicle, for on_vehicle()
##   ride       float   load floor height above the road
##   wheels     Array   [Vector2 centre, radius] for drawing
## cfg "tilt": degrees the whole vehicle leans (+ = rear/left end lower), e.g. parked on a slope.

var base_x := 800.0
var amp := 0.0
var period := 4.0
var shape := {}
var _t := 0.0
var _anim_t := 0.0
var _from_x := 0.0
var _to_x := 0.0
var _last_x := 0.0
var _bump := 0.0
var velocity_x := 0.0
var visual: Node2D
var back_layer: Node2D
var front_layer: Node2D
var wheel_nodes: Array[Node2D] = []

const NAVY = Color("#1B2A41")


func setup(cfg: Dictionary, _palette_index: int, _wall_height: float):
	base_x = cfg.x
	amp = cfg.get("amp", 0.0)
	period = max(0.5, cfg.get("period", 4.0))
	rotation = -deg_to_rad(cfg.get("tilt", 0.0))
	shape = _define(cfg)
	_build_bodies()
	_build_visuals()


## Subclasses: return the shape dictionary (see top of file).
func _define(_cfg: Dictionary) -> Dictionary:
	return {}


## Subclasses: draw behind the cargo / in front of it.
func _draw_back(_n: Node2D):
	pass


func _draw_front(_n: Node2D):
	pass


func floor_y(road_y: float) -> float:
	return road_y - shape.ride


# ---------------------------------------------------------------- bodies + visuals
func _body(group: String, shapes: Array, friction := 1.0, bounce := 0.0) -> AnimatableBody2D:
	var b = AnimatableBody2D.new()
	b.sync_to_physics = false
	b.add_to_group(group)
	var pm = PhysicsMaterial.new()
	pm.friction = friction
	pm.bounce = bounce
	b.physics_material_override = pm
	for sh in shapes:
		var cs = CollisionShape2D.new()
		if sh is Rect2:
			var rs = RectangleShape2D.new()
			rs.size = sh.size
			cs.shape = rs
			cs.position = sh.get_center()
		else:
			var cp = ConvexPolygonShape2D.new()
			cp.points = sh
			cs.shape = cp
		b.add_child(cs)
	add_child(b)
	return b


func _build_bodies():
	_body("truck_floor", [shape.floor])
	_body("truck_wall", [shape.rear] + shape.get("walls", []), 0.8, 0.05)
	if not shape.front.is_empty():
		_body("truck_cab", shape.front, 0.8, 0.05)


func _build_visuals():
	visual = Node2D.new()
	add_child(visual)
	back_layer = Node2D.new()
	back_layer.z_index = -1
	back_layer.draw.connect(func(): _draw_back(back_layer))
	visual.add_child(back_layer)
	front_layer = Node2D.new()
	front_layer.z_index = 2
	front_layer.draw.connect(func(): _draw_front(front_layer))
	visual.add_child(front_layer)
	for w in shape.get("wheels", []):
		var n = Node2D.new()
		n.position = w[0]
		n.z_index = 3
		var r: float = w[1]
		n.draw.connect(func():
			n.draw_circle(Vector2.ZERO, r, Color("#2E3440"))
			n.draw_circle(Vector2.ZERO, r * 0.45, Color("#C9CED6"))
			for i in 4:
				var a = i * PI / 2
				n.draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * r * 0.42, Color("#8A929E"), 3.0)
			n.draw_circle(Vector2.ZERO, 4, Color("#2E3440")))
		visual.add_child(n)
		wheel_nodes.append(n)


# ---------------------------------------------------------------- motion
func arrive():
	state = "arriving"
	_from_x = 1560.0
	_to_x = base_x
	_anim_t = 0.0
	position.x = _from_x
	_last_x = position.x
	reset_physics_interpolation()
	Sfx.play("whoosh", -10.0, 0.8)


func leave():
	glue_all()
	state = "leaving"
	_from_x = position.x
	_to_x = 1700.0
	_anim_t = 0.0
	Sfx.play("honk", -4.0, 1.15)


func _physics_process(delta: float):
	match state:
		"arriving":
			_anim_t = min(1.0, _anim_t + delta / 1.0)
			position.x = lerp(_from_x, _to_x, 1.0 - pow(1.0 - _anim_t, 3))
			if _anim_t >= 1.0:
				state = "parked"
				_t = 0.0
				arrived.emit()
		"parked":
			_t += delta
			if amp > 0:
				position.x = base_x + amp * sin(TAU * _t / period)
		"leaving":
			_anim_t = min(1.0, _anim_t + delta / 1.1)
			position.x = lerp(_from_x, _to_x, _anim_t * _anim_t)
			if _anim_t >= 1.0:
				state = "away"
				for l in loads:
					if is_instance_valid(l.cargo):
						l.cargo.queue_free()
				loads.clear()
				departed.emit()
				queue_free()
				return
	for l in loads:
		var c: Cargo = l.cargo
		if is_instance_valid(c) and c.freeze:
			c.global_position = global_position + l.offset
			c.rotation = l.rot
	var dx = position.x - _last_x
	_last_x = position.x
	velocity_x = dx / delta if delta > 0 else 0.0
	for w in wheel_nodes:
		w.rotation += dx / 26.0
	if _bump > 0:
		_bump = max(0.0, _bump - delta * 6.0)
		visual.position.y = sin(_bump * PI) * 3.0


# ---------------------------------------------------------------- loads
func contains_point(p: Vector2) -> bool:
	return shape.zone.has_point(to_local(p))


func on_vehicle(p: Vector2) -> bool:
	return shape.reach.has_point(to_local(p))


func point_velocity(_p: Vector2) -> Vector2:
	return Vector2(velocity_x, 0)


func add_load(c: Cargo, counted := true):
	loads.append({"cargo": c, "offset": c.global_position - global_position, "rot": c.rotation,
		"local": to_local(c.global_position), "lrot": c.rotation - rotation, "counted": counted})
	_bump = 1.0


func glue_all():
	for l in loads:
		var c: Cargo = l.cargo
		if not is_instance_valid(c) or c.freeze:
			continue
		c.freeze = true
		c.linear_velocity = Vector2.ZERO
		c.angular_velocity = 0.0
		l.offset = c.global_position - global_position
		l.rot = c.rotation


func remove_load(c: Cargo) -> bool:
	for i in loads.size():
		if loads[i].cargo == c:
			var counted: bool = loads[i].counted
			loads.remove_at(i)
			return counted
	return false


func top_center() -> Vector2:
	return global_position + Vector2(0, shape.zone.position.y - 20)


# ---------------------------------------------------------------- QA bot interface
func predict_pose(dt: float) -> Array:
	var p = global_position
	if amp > 0:
		p.x = base_x + amp * sin(TAU * (_t + dt) / period)
	return [p, rotation]


func predict_vx(dt: float) -> float:
	if amp <= 0:
		return 0.0
	return amp * TAU / period * cos(TAU * (_t + dt) / period)


func sim_profile() -> Dictionary:
	var rear: Rect2 = shape.rear
	var fx0 = INF
	var fx1 = -INF
	var fh = 0.0
	for f in shape.front + shape.get("walls", []):
		var r: Rect2 = f if f is Rect2 else _poly_rect(f)
		fx0 = min(fx0, r.position.x)
		fx1 = max(fx1, r.end.x)
		fh = max(fh, -r.position.y)
	if fx0 == INF:
		fx0 = shape.floor_w * 0.5
		fx1 = fx0
	return {"floor_w": shape.floor_w, "rear_t": rear.size.x, "rear_h": -rear.position.y,
		"front_x0": fx0, "front_w": fx1 - fx0, "front_h": fh, "slippery": false, "aim_x": shape.get("aim_x"),
		"tight": true}  # small vehicles: the bot keeps half a box (not a spinning corner) off the walls


static func _poly_rect(poly: PackedVector2Array) -> Rect2:
	var r = Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r
