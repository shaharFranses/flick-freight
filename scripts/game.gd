class_name Game
extends Node2D
## One level: builds the scene (sky, road, dock, obstacles, truck), runs the
## cargo queue, handles slingshot aiming and decides the result.

signal progress_changed(delivered: int, remaining: int)
signal queue_changed(types: Array)
signal popup(text: String, pos: Vector2, color: Color, size: int)
signal first_throw
signal finished(stars: int, delivered: int, total: int)

const ROAD_Y := 625.0
const DOCK_TOP := 430.0
const DOCK_RIGHT := 315.0
const BELT_RIGHT := 189.0
const FLICK_X := 235.0
const MAX_PULL := 170.0
const POWER := 6.6
const GRAVITY := 1200.0
const TILE := 63.0  # Kenney 70px tiles at 0.9
const NEXT_DELAY := 0.65

const C_GOOD = Color("#3DDC97")
const C_GOLD = Color("#FFD34E")
const C_BAD = Color("#FF6B57")

static var verbose := false

var level_index := 0
var level: Dictionary
var queue: Array = []
var current: Cargo = null
var current_ready := false
var truck: Truck = null
var truck_count := 0
var delivered := 0
var thrown := 0
var in_flight := 0
var ended := false
var wind := 0.0
var cap := 99

var aiming := false
var press_pos := Vector2.ZERO
var pull := Vector2.ZERO
var rest_pos := Vector2.ZERO

var world: Node2D
var cargo_root: Node2D
var fx_root: Node2D
var aim: Node2D
var beacon: Sprite2D
var clouds: Array[Sprite2D] = []
var flag: Node2D
var _time := 0.0


func setup(index: int):
	level_index = index
	level = Levels.get_level(index)
	queue = Levels.cargo_list(index)
	wind = level.get("wind", 0.0)
	cap = level.get("cap", 99)
	world = self
	_build_background()
	_build_road()
	_build_dock()
	_build_blocks()
	if wind != 0.0:
		_build_flag()
	cargo_root = Node2D.new()
	add_child(cargo_root)
	fx_root = Node2D.new()
	fx_root.z_index = 20
	add_child(fx_root)
	aim = Node2D.new()
	aim.z_index = 30
	aim.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	aim.draw.connect(_draw_aim)
	add_child(aim)


func start():
	_new_truck()
	get_tree().create_timer(0.35, false).timeout.connect(spawn_next)
	queue_changed.emit(remaining_types())
	progress_changed.emit(delivered, queue.size())


# ======================================================================= build
func _static_node() -> Node2D:
	var n = Node2D.new()
	n.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(n)
	return n


func _build_background():
	var w = Levels.world_of(level_index)
	var bg = Sprite2D.new()
	bg.texture = load(w.bg)
	bg.centered = false
	bg.scale = Vector2(1.25, 1.25)
	bg.position = Vector2(0, -250)
	bg.z_index = -20
	bg.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(bg)
	var ctex = load("res://art/v2/bg/clouds.png")
	for i in 2:
		var c = Sprite2D.new()
		c.texture = ctex
		c.centered = false
		c.scale = Vector2(1.3, 0.8)
		c.position = Vector2(i * 1024 * 1.3, -60)
		c.modulate = Color(1, 1, 1, 0.55)
		c.z_index = -19
		c.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(c)
		clouds.append(c)


func _build_road():
	var road = _static_node()
	road.z_index = -10
	road.draw.connect(func():
		road.draw_rect(Rect2(0, ROAD_Y - 16, 1280, 16), Color("#D3D8DF"))
		road.draw_rect(Rect2(0, ROAD_Y - 16, 1280, 4), Color("#EEF1F4"))
		road.draw_rect(Rect2(0, ROAD_Y, 1280, 100), Color("#5B6170"))
		road.draw_rect(Rect2(0, ROAD_Y, 1280, 5), Color("#4A4F5C"))
		var x = -20.0
		while x < 1300:
			road.draw_rect(Rect2(x, ROAD_Y + 46, 56, 7), Color("#F2F2EC"))
			x += 110.0)
	var ground = StaticBody2D.new()
	ground.add_to_group("ground")
	var pm = PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.05
	ground.physics_material_override = pm
	var cs = CollisionShape2D.new()
	var rs = RectangleShape2D.new()
	rs.size = Vector2(3000, 200)
	cs.shape = rs
	cs.position = Vector2(640, ROAD_Y + 100)
	ground.add_child(cs)
	add_child(ground)


func _tile(parent: Node, file: String, pos: Vector2, z := 0) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = load(file)
	s.centered = false
	s.scale = Vector2(0.9, 0.9)
	s.position = pos
	s.z_index = z
	s.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(s)
	return s


func _build_dock():
	var dock = _static_node()
	dock.z_index = 1
	# conveyor belt (left) feeding the loading spot (right)
	var belts = ["ind_049", "ind_050", "ind_051"]
	for i in 3:
		_tile(dock, "res://art/v2/tiles/%s.png" % belts[i], Vector2(i * TILE, DOCK_TOP))
	var y = DOCK_TOP + 27
	while y < ROAD_Y:
		for i in 3:
			_tile(dock, "res://art/v2/tiles/ind_005.png", Vector2(i * TILE, y))
		y += TILE
	_tile(dock, "res://art/v2/tiles/ind_003.png", Vector2(3 * TILE, DOCK_TOP))
	_tile(dock, "res://art/v2/tiles/ind_003.png", Vector2(4 * TILE, DOCK_TOP))
	y = DOCK_TOP + TILE
	while y < ROAD_Y:
		for i in [3, 4]:
			_tile(dock, "res://art/v2/tiles/ind_005.png", Vector2(i * TILE, y))
		y += TILE
	# hazard stripe on the dock edge and a beacon that lights when cargo is ready
	_tile(dock, "res://art/v2/tiles/ind_065.png", Vector2(3 * TILE, ROAD_Y - 18))
	_tile(dock, "res://art/v2/tiles/ind_065.png", Vector2(4 * TILE, ROAD_Y - 18))
	beacon = _tile(dock, "res://art/v2/tiles/ind_040.png", Vector2(DOCK_RIGHT - 52, DOCK_TOP - TILE))
	var body = StaticBody2D.new()
	body.add_to_group("dock")
	var cs = CollisionShape2D.new()
	var rs = RectangleShape2D.new()
	rs.size = Vector2(DOCK_RIGHT, ROAD_Y - DOCK_TOP)
	cs.shape = rs
	cs.position = Vector2(DOCK_RIGHT * 0.5, (DOCK_TOP + ROAD_Y) * 0.5)
	body.add_child(cs)
	add_child(body)


func _build_blocks():
	for b in level.get("blocks", []):
		var r = Rect2(b[0], b[1], b[2], b[3])
		var body = StaticBody2D.new()
		body.add_to_group("block")
		var pm = PhysicsMaterial.new()
		pm.bounce = 0.3
		body.physics_material_override = pm
		var cs = CollisionShape2D.new()
		var rs = RectangleShape2D.new()
		rs.size = r.size
		cs.shape = rs
		cs.position = r.get_center()
		body.add_child(cs)
		add_child(body)
		var v = _static_node()
		v.z_index = 1
		v.draw.connect(_draw_girder.bind(v, r))


func _draw_girder(n: Node2D, r: Rect2):
	var steel = Color("#AAB4BF")
	var dark = Color("#7D8894")
	n.draw_rect(r, dark)
	n.draw_rect(r.grow(-5), steel)
	var vertical = r.size.y > r.size.x
	if vertical:
		var y = r.position.y + 8
		var flip = false
		while y < r.end.y - 8:
			var y2 = min(y + r.size.x, r.end.y - 6)
			var a = Vector2(r.position.x + 7, y)
			var b = Vector2(r.end.x - 7, y2)
			if flip:
				a.x = r.end.x - 7
				b.x = r.position.x + 7
			n.draw_line(a, b, dark, 4.0)
			flip = not flip
			y = y2
	else:
		var x = r.position.x + 8
		var flip = false
		while x < r.end.x - 8:
			var x2 = min(x + r.size.y, r.end.x - 6)
			var a = Vector2(x, r.position.y + 7)
			var b = Vector2(x2, r.end.y - 7)
			if flip:
				a.y = r.end.y - 7
				b.y = r.position.y + 7
			n.draw_line(a, b, dark, 4.0)
			flip = not flip
			x = x2
		# hazard stripe underneath beams
		var hz = r.end.y - 8
		n.draw_rect(Rect2(r.position.x, hz, r.size.x, 8), Color("#2E3440"))
		var sx = r.position.x
		while sx < r.end.x:
			n.draw_colored_polygon(PackedVector2Array([Vector2(sx, hz + 8), Vector2(sx + 8, hz), Vector2(min(sx + 18, r.end.x), hz), Vector2(min(sx + 10, r.end.x), hz + 8)]), Color("#F2B134"))
			sx += 20
	n.draw_rect(Rect2(r.position, Vector2(r.size.x, 5)), steel.lightened(0.3))


func _build_flag():
	flag = Node2D.new()
	flag.position = Vector2(40, DOCK_TOP)
	flag.z_index = 2
	flag.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	flag.draw.connect(_draw_flag)
	add_child(flag)


func _draw_flag():
	var h = 150.0
	flag.draw_rect(Rect2(-3, -h, 6, h), Color("#7D8894"))
	flag.draw_circle(Vector2(0, -h), 6, Color("#AAB4BF"))
	var dir = sign(wind)
	var length = 40.0 + abs(wind) * 0.35
	var pts = PackedVector2Array()
	var pts2 = PackedVector2Array()
	for i in 9:
		var t = i / 8.0
		var wave = sin(_time * 9.0 - t * 5.0) * 6.0 * t
		pts.append(Vector2(dir * length * t, -h + 2 + wave))
		pts2.append(Vector2(dir * length * t, -h + 32 - 12 * t + wave))
	var poly = pts.duplicate()
	pts2.reverse()
	poly.append_array(pts2)
	flag.draw_colored_polygon(poly, Color("#FF6B57"))
	for i in range(1, 3):
		var t = i / 3.0
		var wave = sin(_time * 9.0 - t * 5.0) * 6.0 * t
		flag.draw_line(Vector2(dir * length * t, -h + 2 + wave), Vector2(dir * length * t, -h + 32 - 12 * t + wave), Color.WHITE, 5.0)


# ======================================================================= trucks
func _new_truck():
	truck = Truck.new()
	truck.setup(level.truck, level_index + truck_count, level.truck.get("wall", 52))
	truck.position = Vector2(1560, ROAD_Y - Truck.FLOOR_T - 18 - Truck.WHEEL_R)
	add_child(truck)
	truck_count += 1
	truck.departed.connect(_on_truck_departed)
	truck.arrive()


func _on_truck_departed():
	truck = null
	if not ended and work_left() > 0:
		_new_truck()


func truck_contains(c: Cargo) -> bool:
	return truck != null and is_instance_valid(truck) and truck.contains_point(c.global_position)


func carrier_velocity(c: Cargo) -> Vector2:
	if truck_contains(c):
		return Vector2(truck.velocity_x, 0)
	return Vector2.ZERO


# ======================================================================= cargo flow
func remaining_types() -> Array:
	var out: Array = []
	if current:
		out.append(current.kind)
	out.append_array(queue)
	return out


func work_left() -> int:
	return queue.size() + (1 if current else 0) + in_flight


func spawn_next():
	if ended or current != null or queue.is_empty():
		return
	var kind: String = queue.pop_front()
	var c = Cargo.new()
	c.setup(kind, self)
	cargo_root.add_child(c)
	rest_pos = Vector2(FLICK_X, DOCK_TOP - c.half_height())
	c.global_position = Vector2(-50, rest_pos.y)
	c.reset_physics_interpolation()
	current = c
	current_ready = false
	Sfx.play("conveyor", -8.0)
	var tw = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(c, "global_position", rest_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): current_ready = true)
	queue_changed.emit(remaining_types())


func can_aim() -> bool:
	return not ended and current != null and current_ready and truck != null and truck.is_parked()


func launch_velocity(p: Vector2) -> Vector2:
	return p * POWER * (current.power_mult() if current else 1.0)


func _unhandled_input(event: InputEvent):
	if ended:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos = make_input_local(event).position
		if event.pressed:
			if can_aim():
				aiming = true
				press_pos = pos
				pull = Vector2.ZERO
				get_viewport().set_input_as_handled()
		elif aiming:
			aiming = false
			get_viewport().set_input_as_handled()
			if pull.length() < 22.0 or not can_aim():
				_cancel_aim()
			else:
				_throw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and aiming:
		aiming = false
		_cancel_aim()
	elif event is InputEventMouseMotion and aiming:
		var pos = make_input_local(event).position
		pull = (press_pos - pos).limit_length(MAX_PULL)
		# never aim backwards into the warehouse
		pull.x = max(pull.x, 0.0)
		if current:
			current.global_position = rest_pos - pull.normalized() * min(pull.length() * 0.16, 24.0)
		aim.queue_redraw()


func _cancel_aim():
	pull = Vector2.ZERO
	if current:
		var tw = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tw.tween_property(current, "global_position", rest_pos, 0.12)
	aim.queue_redraw()


func _throw():
	var c = current
	var vel = launch_velocity(pull)
	current = null
	current_ready = false
	pull = Vector2.ZERO
	aim.queue_redraw()
	c.resolved.connect(_on_resolved)
	c.launch(vel, wind)
	thrown += 1
	in_flight += 1
	Sfx.play("whoosh", -6.0, randf_range(0.95, 1.1))
	if thrown == 1:
		first_throw.emit()
	queue_changed.emit(remaining_types())
	get_tree().create_timer(NEXT_DELAY, false).timeout.connect(spawn_next)


## Used by tests and the demo bot: throw the current cargo with an exact pull vector.
func throw_with_pull(p: Vector2) -> bool:
	if not can_aim():
		return false
	pull = p.limit_length(MAX_PULL)
	_throw()
	return true


func _on_resolved(c: Cargo, ok: bool, reason: String):
	in_flight -= 1
	if verbose:
		print("  cargo %s -> %s (%s) at %s" % [c.kind, "IN" if ok else "out", reason, c.global_position.round()])
	if ok and truck and is_instance_valid(truck):
		delivered += 1
		truck.add_load(c)
		var top = c.global_position + Vector2(0, -50)
		if not c.touched_wall:
			popup.emit("SWISH!", top, C_GOLD, 46)
		else:
			popup.emit("+1", top, C_GOOD, 46)
		Fx.delivered(fx_root, c.global_position)
		Sfx.play("deliver", -5.0, 1.0 + 0.05 * min(delivered, 8))
		if truck.load_count() >= cap and work_left() > 0:
			var t = truck
			get_tree().create_timer(0.45, false).timeout.connect(func():
				if is_instance_valid(t) and t.state == "parked":
					popup.emit("TRUCK FULL!", t.top_center() + Vector2(0, -40), C_GOLD, 40)
					t.leave())
	else:
		var p = c.global_position
		p.x = clamp(p.x, 80, 1200)
		p.y = clamp(p.y - 40, 160, ROAD_Y - 40)
		if reason == "broken":
			popup.emit("BROKEN!", p, C_BAD, 42)
			Fx.shatter(fx_root, c.global_position, Color("#F2C23B"))
			Sfx.play("break", -2.0)
			c.queue_free()
		else:
			popup.emit("MISS", p, C_BAD, 38)
			Sfx.play("thud", -4.0)
			c.fade_out()
	progress_changed.emit(delivered, work_left())
	_check_end()


func on_heavy_impact(pos: Vector2, impact: float):
	Fx.dust(fx_root, pos + Vector2(0, 20), clamp(impact / 900.0, 0.3, 1.2))


func _check_end():
	if ended:
		return
	var left = work_left()
	var lost_cause = delivered + left < level.goal
	if left == 0 or (lost_cause and in_flight == 0):
		ended = true
		aiming = false
		aim.queue_redraw()
		var stars = Levels.stars_for(level_index, delivered)
		SaveData.set_stars(level_index, stars)
		get_tree().create_timer(0.9, false).timeout.connect(func():
			finished.emit(stars, delivered, level.cargo.length()))


# ======================================================================= per-frame
func _process(delta: float):
	_time += delta
	for c in clouds:
		c.position.x -= delta * 12.0
		if c.position.x < -1024 * 1.3:
			c.position.x += 2 * 1024 * 1.3
	if beacon:
		var on = can_aim()
		beacon.modulate = Color(1, 1, 1, 1) if not on else Color(1.0, 1.0 + 0.25 * sin(_time * 10.0), 1.0, 1.0)
	if flag:
		flag.queue_redraw()


func _draw_aim():
	if not aiming or current == null or pull.length() < 6.0:
		return
	var p0 = current.global_position
	var v = launch_velocity(pull)
	var acc = Vector2(wind, GRAVITY)
	var guide: float = level.get("guide", 1.0)
	var t_max = 0.25 + 1.15 * guide
	var dt = 1.0 / 60.0
	var p = p0
	var t = 0.0
	var i = 0
	var blocks: Array = []
	for b in level.get("blocks", []):
		blocks.append(Rect2(b[0], b[1], b[2], b[3]))
	while t < t_max:
		v += acc * dt
		p += v * dt
		t += dt
		i += 1
		if p.y > ROAD_Y:
			break
		var hit = false
		for r in blocks:
			if r.has_point(p):
				hit = true
		if hit:
			break
		if i % 4 == 0:
			var k = t / t_max
			var r = lerp(8.0, 4.0, k)
			var a = lerp(1.0, 0.25, k)
			aim.draw_circle(p, r + 2.5, Color(0.106, 0.165, 0.255, a))
			aim.draw_circle(p, r, Color(1, 1, 1, a))
	# pull band from the rest spot to the cargo
	aim.draw_line(rest_pos, p0, Color(0.106, 0.165, 0.255, 0.6), 4.0)
	var strength = pull.length() / MAX_PULL
	aim.draw_arc(p0, 46, -PI / 2, -PI / 2 + TAU * strength, 32, C_GOLD.lerp(C_BAD, strength * strength), 6.0)
