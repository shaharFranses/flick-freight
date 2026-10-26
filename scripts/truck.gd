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

var _t := 0.0
var _anim_t := 0.0
var _from_x := 0.0
var _to_x := 0.0
var _last_x := 0.0
var _bump := 0.0
var velocity_x := 0.0

var floor_body: AnimatableBody2D
var wall_body: AnimatableBody2D
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
	pm.friction = 1.0
	pm.bounce = 0.0
	floor_body.physics_material_override = pm
	_rect_shape(floor_body, Vector2(0, FLOOR_T * 0.5), Vector2(BED_W + WALL_T * 2, FLOOR_T))
	add_child(floor_body)

	wall_body = AnimatableBody2D.new()
	wall_body.sync_to_physics = false
	wall_body.add_to_group("truck_wall")
	var pm2 = PhysicsMaterial.new()
	pm2.bounce = 0.25
	pm2.friction = 0.6
	wall_body.physics_material_override = pm2
	# rear tailgate (left), bulkhead (right) and the cab block
	_rect_shape(wall_body, Vector2(-BED_W * 0.5 - WALL_T * 0.5, -wall_h * 0.5), Vector2(WALL_T, wall_h))
	_rect_shape(wall_body, Vector2(BED_W * 0.5 + WALL_T * 0.5, -FRONT_H * 0.5), Vector2(WALL_T, FRONT_H))
	var cab_x0 = BED_W * 0.5 + WALL_T + 4
	_rect_shape(wall_body, Vector2(cab_x0 + CAB_W * 0.5, -55 + FLOOR_T * 0.5), Vector2(CAB_W, 110 + FLOOR_T))
	add_child(wall_body)


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
	var cab = PackedVector2Array([
		Vector2(cab_x0, FLOOR_T), Vector2(cab_x0, -112), Vector2(cab_x0 + 78, -112),
		Vector2(cab_x0 + 112, -62), Vector2(cab_x0 + CAB_W, -54), Vector2(cab_x0 + CAB_W, FLOOR_T)])
	front_layer.draw_colored_polygon(cab, body)
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
	# carried cargo follows the truck
	for l in loads:
		var c: Cargo = l.cargo
		if is_instance_valid(c):
			c.global_position = global_position + l.offset
			c.rotation = l.rot
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


# ---------------------------------------------------------------- loads
func contains_point(p: Vector2) -> bool:
	var l = p - global_position
	return abs(l.x) < BED_W * 0.5 - 4 and l.y < 0 and l.y > -300


func add_load(c: Cargo):
	c.freeze = true
	c.linear_velocity = Vector2.ZERO
	c.angular_velocity = 0.0
	loads.append({"cargo": c, "offset": c.global_position - global_position, "rot": c.rotation})
	bump()


func load_count() -> int:
	return loads.size()


func top_center() -> Vector2:
	return global_position + Vector2(0, -wall_h - 20)
