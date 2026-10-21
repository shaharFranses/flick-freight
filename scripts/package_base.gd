extends RigidBody2D

# Package properties (to be set by child scenes)
@export var package_mass: float = 1.0
@export var bay_hitbox_scale: float = 1.0
@export var points: int = 1

# Physics constants from design brief
# TUNED for far-bay reach: Raised max_speed 900→2000, reduced gravity 1400→900
# to ensure strong flick CLEARLY overshoots far bay. Near-bay still requires aim.
const IMPULSE_MULTIPLIER = 8.5
const MIN_SPEED = 220.0
const MAX_SPEED = 2000.0  # Raised from 1500 for guaranteed far-bay reach
const DRAG_DEADZONE = 12.0
const GRAVITY = 900.0      # Reduced from 1100 for higher arc
const AIR_DRAG = 0.02

# Flick input state
var is_dragging: bool = false
var drag_start_pos: Vector2
var drag_current_pos: Vector2
var has_been_flicked: bool = false
var mouse_over: bool = false
var has_scored: bool = false

# CRITICAL: Stable credit key set once on ready
var credit_key: String = ""

# Signals
signal landed(points: int)
signal missed

func _ready():
	# IMMUTABLE: Set credit_key ONCE using stable instance_id
	# NEVER regenerate with Time - that creates different keys
	credit_key = str(get_instance_id())
	
	# Add to packages group for identification
	add_to_group("packages")
	
	print("PKG: Ready - credit_key:", credit_key, " (instance_id)")
	
	# Set up physics
	gravity_scale = GRAVITY / 980.0  # Godot default gravity is 980 (now 900/980 ≈ 0.918)
	mass = package_mass
	linear_damp = AIR_DRAG
	freeze = true  # Start frozen until flicked
	
	# Start at spawn position (bottom center)
	position = Vector2(360, 1150)  # Near bottom of 1280 height
	
	# r4: vector cargo art (same footprint as the collision box)
	for c in get_children():
		if c is CanvasItem:
			c.visible = false
	add_child(Art.build_cargo_scaled(Art.type_from_points(points)))
	_make_aim()
	
	# M5 FIX: Connect body_entered to detect ground/truck hits for immediate miss
	body_entered.connect(_on_body_entered_miss_check)

# Helper methods for TruckBay to check package state
func is_package_flicked() -> bool:
	return has_been_flicked

func get_package_points() -> int:
	return points

func get_credit_key() -> String:
	return credit_key

func _input(event):
	if has_been_flicked:
		return
	
	# H5 FIX: Deduplicate mouse/touch - emulate_touch_from_mouse is enabled
	# so we only handle mouse events (touch is emulated as mouse)
	var input_pos: Vector2
	var is_press: bool = false
	var is_release: bool = false
	var is_drag: bool = false
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		input_pos = event.position
		is_press = event.pressed
		is_release = !event.pressed
	elif event is InputEventMouseMotion and is_dragging:
		input_pos = event.position
		is_drag = true
	else:
		return  # Ignore touch events (emulated to mouse already)
	
	# Check if mouse is over package (simple circle check)
	if is_press or (is_drag and !is_dragging):
		# r5: use the event's own position (canvas space). get_global_mouse_position() can be
		# stale on the first press after a retry / on a touch with no prior hover motion.
		var press_world = get_canvas_transform().affine_inverse() * input_pos
		var dist = global_position.distance_to(press_world)
		mouse_over = dist < 50
	
	if is_press and mouse_over:
		start_drag(input_pos)
	elif is_release and is_dragging:
		end_drag(input_pos)
	elif is_drag:
		drag_current_pos = input_pos

# ---------- r4: aim / trajectory dots while dragging (display only) ----------
const AIM_DOTS = 14
var _aim_hold_until := 0.0
var aim_root: Node2D = null

func _make_aim():
	aim_root = Node2D.new()
	aim_root.name = "AimDots"
	aim_root.top_level = true
	aim_root.z_index = 40
	aim_root.visible = false
	for i in AIM_DOTS:
		var d = Polygon2D.new()
		var r = lerp(10.0, 5.5, float(i) / AIM_DOTS)
		d.polygon = Art.circle(Vector2.ZERO, r, 10)
		d.color = Art.NAVY  # full alpha at every point
		var ol = Line2D.new()
		var pts = Art.circle(Vector2.ZERO, r, 10); pts.append(pts[0])
		ol.points = pts; ol.width = 3.0; ol.default_color = Color(1, 1, 1, 1)
		d.add_child(ol)
		aim_root.add_child(d)
	# drawn on the UI canvas layer so the arc sits above the hint text (same 720x1280 coords)
	var ui = get_tree().root.get_node_or_null("Main/UIManager/UI")
	if ui:
		aim_root.top_level = false
		aim_root.z_index = 50
		ui.add_child.call_deferred(aim_root)
		tree_exiting.connect(func():
			if is_instance_valid(aim_root): aim_root.queue_free())
	else:
		add_child(aim_root)

func _process(_delta):
	if aim_root == null:
		return
	if _aim_hold_until > 0.0:
		if Time.get_ticks_msec() / 1000.0 < _aim_hold_until:
			return  # ?qa=1&hold_aim=1: keep the last arc on screen (display only)
		_aim_hold_until = 0.0
	if !is_dragging or has_been_flicked:
		aim_root.visible = false
		return
	var dv = drag_current_pos - drag_start_pos
	# drag is in screen space; convert to world-space length the same way the flick does
	if dv.length() < DRAG_DEADZONE or dv.y > -2.0:
		aim_root.visible = false
		return
	var speed = clamp(dv.length() * IMPULSE_MULTIPLIER, MIN_SPEED, MAX_SPEED)
	var v = dv.normalized() * speed
	var g = Vector2(0, GRAVITY)
	aim_root.visible = true
	var t_step = 0.045
	var p0 = global_position
	for i in AIM_DOTS:
		var t = t_step * (i + 1)
		var p = p0 + v * t + 0.5 * g * t * t
		var d = aim_root.get_child(i)
		d.global_position = p
		d.visible = p.y > 120.0

func start_drag(pos: Vector2):
	is_dragging = true
	drag_start_pos = pos
	drag_current_pos = pos

func end_drag(pos: Vector2):
	if !is_dragging:
		return
		
	is_dragging = false
	drag_current_pos = pos
	
	# FIX: Swipe direction is current - start (not start - current)
	var drag_vector = drag_current_pos - drag_start_pos
	var drag_distance = drag_vector.length()
	
	# Check deadzone
	if drag_distance < DRAG_DEADZONE:
		return
	
	# Calculate impulse (speed is desired velocity, mass scaling happens in apply_central_impulse)
	var speed = clamp(drag_distance * IMPULSE_MULTIPLIER, MIN_SPEED, MAX_SPEED)
	var direction = drag_vector.normalized()
	var gm = get_node_or_null("/root/Main/GameManager")
	if gm and gm.has_method("on_flick"):
		var o = gm.on_flick(direction, speed)
		direction = o[0]
		speed = o[1]
	var impulse = direction * speed * package_mass  # FIX H4: multiply by mass, not divide
	
	# Apply impulse
	freeze = false
	apply_central_impulse(impulse)  # This divides by mass internally, so we get desired velocity
	has_been_flicked = true
	for cn in ["CurrentChip", "CurrentChipBg"]:  # r4: the CURRENT tag stays behind on launch
		var c = get_node_or_null(cn)
		if c: c.visible = false
	var _gm = get_tree().root.get_node_or_null("Main/GameManager")
	if _gm and _gm.qa_mode and _gm.qa_hold_aim and aim_root and aim_root.visible:
		_aim_hold_until = Time.get_ticks_msec() / 1000.0 + 4.0
		print("QA hold_aim: arc frozen 4s")
	
	# Start checking for hit/miss
	check_outcome()

# NOTE: This method is deprecated - TruckBay now calls GameManager.register_successful_load directly
# Kept for backward compatibility but should not be used for load counting
func try_score_hit(bay):
	print("PKG: try_score_hit called (DEPRECATED - should use direct GameManager call)")
	return

func _on_body_entered_miss_check(body):
	# M5 FIX: Emit miss immediately on ground/truck body hit
	if !has_been_flicked or has_scored:
		return
	
	# If we hit ground or any static body (not the bay), it's a miss
	if body is StaticBody2D:
		has_scored = true  # Prevent double-miss
		missed.emit()
		queue_free()

func check_outcome():
	# Check periodically if package is off screen - ONLY IF FLICKED
	# Un-flicked packages must never time out
	if !has_been_flicked:
		return
	
	var check_timer = 0.0
	while check_timer < 5.0 and !is_queued_for_deletion():
		await get_tree().create_timer(0.2).timeout
		check_timer += 0.2
		
		# Check if off screen
		if position.y < -200 or position.x < -200 or position.x > 920 or position.y > 1500:
			if !is_queued_for_deletion() and !has_scored:
				missed.emit()
				queue_free()
			return
	
	# Timeout - count as miss if not scored
	if !is_queued_for_deletion() and !has_scored:
		missed.emit()
		queue_free()

# H1: Optional ghost arc (0.2s trajectory preview)
func show_ghost_arc():
	if !is_dragging or drag_current_pos.distance_to(drag_start_pos) < DRAG_DEADZONE:
		return
	
	# Calculate predicted trajectory
	var drag_vector = drag_current_pos - drag_start_pos
	var speed = clamp(drag_vector.length() * IMPULSE_MULTIPLIER, MIN_SPEED, MAX_SPEED)
	var direction = drag_vector.normalized()
	var velocity = direction * speed
	
	# Draw arc for 0.2s
	var steps = 5
	var dt = 0.2 / steps
	var gravity_vec = Vector2(0, GRAVITY)
	
	# This would draw the arc - simplified stub for now
	# In full implementation, would use Line2D or draw calls
	pass
