class_name Truck
extends Node2D
## Side-view stake-bed truck. Origin = centre of the bed floor's top surface.
## Rear (open) end faces the dock on the left; cab on the right.

signal arrived
signal departed

const BED_W := 270.0
const WALL_T := 14.0
const FLOOR_T := 22.0
const FRONT_H := 120.0
const WHEEL_R := 30.0
const CAB_W := 150.0
const PALETTES = [
	[Color("#E4572E"), Color("#B83F1F")],
	[Color("#3D8BDB"), Color("#2A6BB0")],
	[Color("#2EAE6B"), Color("#1E8350")],
	[Color("#F2B134"), Color("#C98E1D")],
	[Color("#8E5BD6"), Color("#6A3FAE")],
]
## Colour-coded trucks (M9): colour + a shape so it never relies on colour alone.
const CARGO_COLORS = [Color("#E4572E"), Color("#3D8BDB"), Color("#F2B134")]
const COLOR_NAMES = ["RED", "BLUE", "YELLOW"]
const COLOR_PALETTES = [
	[Color("#E4572E"), Color("#B83F1F")],
	[Color("#3D8BDB"), Color("#2A6BB0")],
	[Color("#F2B134"), Color("#C98E1D")],
]
const NAVY = Color("#1B2A41")
const WOOD = Color("#A87444")
const WOOD_DARK = Color("#7A4E2A")
const WOOD_LINE = Color("#93633A")
const GLASS = Color("#BFE7F7")
const TYRE = Color("#2E3440")
const HUB = Color("#C9CED6")

var wall_h := 52.0
var base_x := 800.0
var amp := 0.0
var period := 4.0
var palette: Array
var state := "away"  # away / arriving / parked / leaving
var loads: Array = []  # [{"cargo": Cargo, "offset": Vector2, "rot": float}]
var color := -1  # M9: index into CARGO_COLORS, -1 = takes any cargo
var ferry: Dictionary = {}  # M10: {amp_y, amp_rot (deg), period}; empty = on the road
var icy := false  # M11: icy bed, everything slides
var height_limit := 0.0  # M14: bridge line above the bed (0 = none)

var _t := 0.0
var _anim_t := 0.0
var _from_x := 0.0
var _to_x := 0.0
var _last_x := 0.0
var _bump := 0.0
var velocity_x := 0.0
var velocity_y := 0.0
var angular_velocity := 0.0
var _ferry_t := 0.0
var _base_y := 0.0
var _last_y := 0.0
var _last_rot := 0.0

var floor_body: AnimatableBody2D
var wall_body: AnimatableBody2D
var cab_body: AnimatableBody2D
var visual: Node2D
var back_layer: Node2D
var front_layer: Node2D
var wheels: Array[Node2D] = []


func setup(cfg: Dictionary, palette_index: int, wall_height: float):
	base_x = cfg.x
	amp = cfg.get("amp", 0.0)
	period = max(0.5, cfg.get("period", 4.0))
	wall_h = wall_height
	palette = PALETTES[palette_index % PALETTES.size()]
	color = cfg.get("color", -1)
	if color >= 0:
		palette = COLOR_PALETTES[color]
	ferry = cfg.get("ferry", {})
	icy = cfg.get("icy", false)
	_build_bodies()
	_build_visuals()


# ---------------------------------------------------------------- physics bodies
func _rect_shape(parent: Node, center: Vector2, size: Vector2):
	var cs = CollisionShape2D.new()
	var rs = RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	cs.position = center
	parent.add_child(cs)


func _build_bodies():
	floor_body = AnimatableBody2D.new()
	floor_body.sync_to_physics = false
	floor_body.add_to_group("truck_floor")
	var pm = PhysicsMaterial.new()
	pm.friction = 0.02 if icy else 1.0
	pm.bounce = 0.0
	floor_body.physics_material_override = pm
	_rect_shape(floor_body, Vector2(0, FLOOR_T * 0.5), Vector2(BED_W + WALL_T * 2, FLOOR_T))
	add_child(floor_body)

	wall_body = AnimatableBody2D.new()
	wall_body.sync_to_physics = false
	wall_body.add_to_group("truck_wall")
	var pm2 = PhysicsMaterial.new()
	pm2.bounce = 0.05
	pm2.friction = 0.8
	wall_body.physics_material_override = pm2
	# rear tailgate (left), bulkhead (right) and the cab block
	_rect_shape(wall_body, Vector2(-BED_W * 0.5 - WALL_T * 0.5, -wall_h * 0.5), Vector2(WALL_T, wall_h))
	_rect_shape(wall_body, Vector2(BED_W * 0.5 + WALL_T * 0.5, -FRONT_H * 0.5), Vector2(WALL_T, FRONT_H))
	add_child(wall_body)

	# cab: its own body so landing on it is an instant miss; shape matches the drawn cab
	cab_body = AnimatableBody2D.new()
	cab_body.sync_to_physics = false
	cab_body.add_to_group("truck_cab")
	cab_body.physics_material_override = pm2
	var cs = CollisionShape2D.new()
	var shape = ConvexPolygonShape2D.new()
	shape.points = cab_points()
	cs.shape = shape
	cab_body.add_child(cs)
	add_child(cab_body)


func cab_points() -> PackedVector2Array:
	var x0 = BED_W * 0.5 + WALL_T + 4
	return PackedVector2Array([
		Vector2(x0, FLOOR_T), Vector2(x0, -112), Vector2(x0 + 78, -112),
		Vector2(x0 + 112, -62), Vector2(x0 + CAB_W, -54), Vector2(x0 + CAB_W, FLOOR_T)])


# ---------------------------------------------------------------- visuals
func _build_visuals():
	visual = Node2D.new()
	add_child(visual)
	back_layer = Node2D.new()
	back_layer.z_index = -1
	back_layer.draw.connect(_draw_back)
	visual.add_child(back_layer)
	front_layer = Node2D.new()
	front_layer.z_index = 2
	front_layer.draw.connect(_draw_front)
	visual.add_child(front_layer)
	var cab_x0 = BED_W * 0.5 + WALL_T + 4
	for wx in [-BED_W * 0.5 + 58, BED_W * 0.5 - 50, cab_x0 + CAB_W - 52]:
		var w = Node2D.new()
		w.position = Vector2(wx, FLOOR_T + 18)
		w.z_index = 3
		w.draw.connect(_draw_wheel.bind(w))
		visual.add_child(w)
		wheels.append(w)


func _draw_back():
	var L = -BED_W * 0.5
	if not ferry.is_empty():
		_draw_ferry_hull()
	# far side of the bed (behind the cargo)
	back_layer.draw_rect(Rect2(L, -wall_h, BED_W, wall_h), WOOD_DARK)
	for i in range(1, 4):
		var y = -wall_h * i / 4.0
		back_layer.draw_line(Vector2(L, y), Vector2(-L, y), WOOD_LINE.darkened(0.25), 2.0)
	# bulkhead inner face
	back_layer.draw_rect(Rect2(-L, -FRONT_H, WALL_T, FRONT_H), palette[1])


func _draw_front():
	var L = -BED_W * 0.5
	var dark: Color = palette[1]
	var body: Color = palette[0]
	var cab_x0 = BED_W * 0.5 + WALL_T + 4
	# chassis + bed floor
	front_layer.draw_rect(Rect2(L - WALL_T, 0, BED_W + WALL_T * 2 + CAB_W + 4, FLOOR_T), dark)
	front_layer.draw_rect(Rect2(L - WALL_T, 0, BED_W + WALL_T * 2, 7), WOOD)
	# rear tailgate post
	front_layer.draw_rect(Rect2(L - WALL_T, -wall_h, WALL_T, wall_h), body)
	front_layer.draw_rect(Rect2(L - WALL_T, -wall_h, WALL_T, 6), body.lightened(0.25))
	# side rails (near side): top rail + mid rail, with posts. Cargo shows between them.
	front_layer.draw_rect(Rect2(L, -wall_h, BED_W, 9), WOOD)
	front_layer.draw_rect(Rect2(L, -wall_h, BED_W, 3), WOOD.lightened(0.2))
	front_layer.draw_rect(Rect2(L, -wall_h * 0.45, BED_W, 7), WOOD)
	for px in [L + BED_W * 0.33, L + BED_W * 0.66]:
		front_layer.draw_rect(Rect2(px - 4, -wall_h, 8, wall_h), WOOD_DARK)
	# bulkhead
	front_layer.draw_rect(Rect2(-L, -FRONT_H, WALL_T, FRONT_H), body)
	front_layer.draw_rect(Rect2(-L, -FRONT_H, WALL_T, 6), body.lightened(0.25))
	# cab
	front_layer.draw_colored_polygon(cab_points(), body)
	front_layer.draw_rect(Rect2(cab_x0, -112, 78, 6), body.lightened(0.25))
	var win = PackedVector2Array([
		Vector2(cab_x0 + 52, -100), Vector2(cab_x0 + 76, -100), Vector2(cab_x0 + 102, -64), Vector2(cab_x0 + 52, -64)])
	front_layer.draw_colored_polygon(win, GLASS)
	front_layer.draw_line(Vector2(cab_x0 + 58, -94), Vector2(cab_x0 + 66, -72), Color(1, 1, 1, 0.7), 4.0)
	front_layer.draw_rect(Rect2(cab_x0 + 8, -100, 36, 30), GLASS)
	# door + handle + stripe
	front_layer.draw_rect(Rect2(cab_x0 + 6, -58, 2, 72), dark)
	front_layer.draw_rect(Rect2(cab_x0 + 18, -40, 14, 4), dark)
	front_layer.draw_rect(Rect2(cab_x0, -30, CAB_W, 8), Color(1, 1, 1, 0.85))
	# headlight + bumper
	front_layer.draw_rect(Rect2(cab_x0 + CAB_W - 10, -44, 10, 12), Color("#FFE27A"))
	front_layer.draw_rect(Rect2(cab_x0 + CAB_W - 6, 4, 16, 14), Color("#AEB6C2"))
	front_layer.draw_rect(Rect2(L - WALL_T - 8, 4, 12, 14), Color("#AEB6C2"))
	front_layer.draw_rect(Rect2(L - WALL_T - 6, -6, 8, 8), Color("#E23B3B"))  # tail light
	# mudguards
	for w in wheels:
		front_layer.draw_arc(w.position, WHEEL_R + 6, PI, TAU, 16, dark, 6.0)
	if icy:
		front_layer.draw_rect(Rect2(L - WALL_T, -3, BED_W + WALL_T * 2, 9), Color("#BFE7F7"))
		for gx in [L + 30, L + 120, L + 210]:
			front_layer.draw_line(Vector2(gx, 0), Vector2(gx + 22, 0), Color.WHITE, 3.0)
	if height_limit > 0:
		_draw_height_line(L)
	if color >= 0:
		# sign on a post above the bulkhead: readable even with a full bed
		var post = Vector2(-L + WALL_T * 0.5, -FRONT_H)
		front_layer.draw_rect(Rect2(post.x - 4, post.y - 40, 8, 40), Color("#5B6574"))
		draw_color_badge(front_layer, post + Vector2(0, -66), 34.0, color)
		draw_color_badge(front_layer, Vector2(cab_x0 + 40, -2), 18.0, color)


## M14: dashed "low bridge" line: cargo sticking up past it gets knocked off.
func _draw_height_line(L: float):
	var y = -height_limit
	var x = L - WALL_T
	while x < -L:
		front_layer.draw_line(Vector2(x, y), Vector2(min(x + 18, -L), y), NAVY, 7.0)
		front_layer.draw_line(Vector2(x, y), Vector2(min(x + 18, -L), y), Color("#FF6B57"), 4.0)
		x += 28.0
	# little bridge icon at the back end of the line
	var b = Vector2(L - WALL_T - 30, y)
	front_layer.draw_rect(Rect2(b.x - 22, b.y - 14, 44, 10), NAVY)
	front_layer.draw_rect(Rect2(b.x - 20, b.y - 12, 40, 6), Color("#FF6B57"))
	front_layer.draw_rect(Rect2(b.x - 20, b.y - 6, 6, 18), NAVY)
	front_layer.draw_rect(Rect2(b.x + 14, b.y - 6, 6, 18), NAVY)


## Ferry hull the truck rides on; it sails in and out with the truck.
func _draw_ferry_hull():
	var x0 = -BED_W * 0.5 - WALL_T - 50
	var x1 = BED_W * 0.5 + WALL_T + CAB_W + 50
	var deck = FLOOR_T + 18 + WHEEL_R
	var hull = PackedVector2Array([Vector2(x0 - 20, deck), Vector2(x1 + 20, deck),
		Vector2(x1 - 10, deck + 56), Vector2(x0 + 10, deck + 56)])
	back_layer.draw_colored_polygon(hull, Color("#2E4A6B"))
	back_layer.draw_rect(Rect2(x0 - 20, deck, x1 - x0 + 40, 10), Color("#C9CED6"))
	back_layer.draw_rect(Rect2(x0, deck + 22, x1 - x0, 8), Color("#FF6B57"))
	for px in [x0 + 10, x1 - 10]:
		back_layer.draw_rect(Rect2(px - 5, deck - 34, 10, 34), Color("#C9CED6"))
		back_layer.draw_circle(Vector2(px, deck - 34), 7, Color("#FF6B57"))


## Colour badge: filled disc in the colour, white ring, white shape (circle/triangle/square).
static func draw_color_badge(ci: CanvasItem, c: Vector2, r: float, idx: int):
	ci.draw_circle(c, r + 3, NAVY)
	ci.draw_circle(c, r, CARGO_COLORS[idx])
	ci.draw_arc(c, r - 2, 0, TAU, 32, Color.WHITE, max(2.0, r * 0.12))
	var k = r * 0.5
	match idx:
		0:
			ci.draw_circle(c, k, Color.WHITE)
		1:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k * 1.15), c + Vector2(k * 1.05, k * 0.75),
				c + Vector2(-k * 1.05, k * 0.75)]), Color.WHITE)
		_:
			ci.draw_rect(Rect2(c - Vector2(k, k) * 0.85, Vector2(k, k) * 1.7), Color.WHITE)


func _draw_wheel(w: Node2D):
	w.draw_circle(Vector2.ZERO, WHEEL_R, TYRE)
	w.draw_circle(Vector2.ZERO, WHEEL_R * 0.45, HUB)
	for i in 4:
		var a = i * PI / 2
		w.draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * WHEEL_R * 0.42, Color("#8A929E"), 3.0)
	w.draw_circle(Vector2.ZERO, 4, TYRE)


# ---------------------------------------------------------------- motion
func arrive():
	state = "arriving"
	_from_x = 1560.0
	_to_x = base_x
	_anim_t = 0.0
	position.x = _from_x
	_last_x = position.x
	_base_y = position.y
	_last_y = position.y
	reset_physics_interpolation()
	Sfx.play("whoosh", -10.0, 0.7)


func leave():
	state = "leaving"
	_from_x = position.x
	_to_x = 1700.0
	_anim_t = 0.0
	Sfx.play("honk", -4.0)
	Sfx.play("truck_full", -6.0)


func is_parked() -> bool:
	return state == "parked"


func bump():
	_bump = 1.0


func _physics_process(delta: float):
	match state:
		"arriving":
			_anim_t = min(1.0, _anim_t + delta / 1.0)
			var e = 1.0 - pow(1.0 - _anim_t, 3)
			position.x = lerp(_from_x, _to_x, e)
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
	if not ferry.is_empty():
		_ferry_motion(delta)
	# carried cargo follows the truck
	for l in loads:
		var c: Cargo = l.cargo
		if is_instance_valid(c):
			if ferry.is_empty():
				c.global_position = global_position + l.offset
				c.rotation = l.rot
			else:
				c.global_position = to_global(l.local)
				c.rotation = rotation + l.lrot
	# wheels spin with distance travelled
	var dx = position.x - _last_x
	_last_x = position.x
	velocity_x = dx / delta if delta > 0 else 0.0
	for w in wheels:
		w.rotation += dx / WHEEL_R
	# landing bump
	if _bump > 0:
		_bump = max(0.0, _bump - delta * 6.0)
		visual.position.y = sin(_bump * PI) * 4.0


## M10: bob up and down and roll a little on the swell.
func _ferry_motion(delta: float):
	_ferry_t += delta
	var period = max(0.5, ferry.get("period", 3.0))
	var ph = TAU * _ferry_t / period
	position.y = _base_y + ferry.get("amp_y", 12.0) * sin(ph)
	rotation = deg_to_rad(ferry.get("amp_rot", 3.0)) * sin(ph + 0.9)
	if delta > 0:
		velocity_y = (position.y - _last_y) / delta
		angular_velocity = (rotation - _last_rot) / delta
	_last_y = position.y
	_last_rot = rotation


## Same as on the road, plus the swell: future position/rotation `dt` seconds ahead (bot).
func ferry_pose(dt: float) -> Array:
	var period = max(0.5, ferry.get("period", 3.0))
	var ph = TAU * (_ferry_t + dt) / period
	return [_base_y + ferry.get("amp_y", 12.0) * sin(ph), deg_to_rad(ferry.get("amp_rot", 3.0)) * sin(ph + 0.9)]


## Velocity of a point riding on the truck.
func point_velocity(p: Vector2) -> Vector2:
	if ferry.is_empty():
		return Vector2(velocity_x, 0)
	var r = p - global_position
	return Vector2(velocity_x, velocity_y) + Vector2(-r.y, r.x) * angular_velocity


# ---------------------------------------------------------------- loads
func _local(p: Vector2) -> Vector2:
	return p - global_position if ferry.is_empty() else to_local(p)


func contains_point(p: Vector2) -> bool:
	var l = _local(p)
	return abs(l.x) < BED_W * 0.5 - 4 and l.y < 0 and l.y > -300


func on_vehicle(p: Vector2) -> bool:
	var l = _local(p)
	return l.x > -BED_W * 0.5 - WALL_T - 40 and l.x < BED_W * 0.5 + WALL_T + CAB_W + 40 and l.y < FLOOR_T


func add_load(c: Cargo):
	c.freeze = true
	c.linear_velocity = Vector2.ZERO
	c.angular_velocity = 0.0
	loads.append({"cargo": c, "offset": c.global_position - global_position, "rot": c.rotation,
		"local": to_local(c.global_position), "lrot": c.rotation - rotation})
	bump()


func load_count() -> int:
	return loads.size()


func top_center() -> Vector2:
	return global_position + Vector2(0, -wall_h - 20)
