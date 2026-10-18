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
var resolved: bool = false  # CRITICAL: Ensure resolve happens exactly once
var flick_time: float = 0.0  # Track when flicked for timeout
var last_flick_direction: Vector2 = Vector2.ZERO  # Store flick dir for validation
var last_flick_impulse: float = 0.0  # Store impulse magnitude for debug

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
	
	# M5 FIX: Connect body_entered to detect ground/truck hits for immediate miss
	body_entered.connect(_on_body_entered_miss_check)

func _physics_process(_delta: float):
	# CRITICAL: After flick, check for offscreen or timeout → force resolve
	if !has_been_flicked or resolved:
		return
	
	# Check offscreen bounds
	var is_offscreen = position.y < -50 or position.y > 1400 or position.x < -100 or position.x > 820
	
	# Check timeout (3s after flick)
	var time_since_flick = Time.get_ticks_msec() / 1000.0 - flick_time
	var is_timeout = time_since_flick > 3.0
	
	if is_offscreen or is_timeout:
		var reason = "offscreen" if is_offscreen else "timeout (%.1fs)" % time_since_flick
		print("PKG: RESOLVE TRIGGER - ", reason, " at pos:", position)
		_resolve_miss()

func _resolve_miss():
	# Ensure this runs exactly once
	if resolved:
		return
	
	resolved = true
	print("🚨 RESOLVE CALLED - Package miss")
	
	# Disable collision
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	
	# Notify GameManager directly
	var game_manager = get_node_or_null("/root/Main/GameManager")
	if game_manager and game_manager.has_method("_on_package_missed"):
		print("  → Calling GameManager._on_package_missed()")
		game_manager._on_package_missed()
	
	# Clean up
	queue_free()

# Helper methods for TruckBay to check package state
func is_package_flicked() -> bool:
	return has_been_flicked

func get_package_points() -> int:
	return points

func get_credit_key() -> String:
	return credit_key

func get_last_flick_direction() -> Vector2:
	return last_flick_direction

func _input(event):
	if has_been_flicked:
		return
	
	# BUBBLE-SHOOTER INPUT LOCK: Prevent flicks during conveyor advance
	var game_manager = get_tree().root.get_node("Main/GameManager")
	if game_manager and game_manager.is_advancing:
		return  # Input locked during tween
	
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
		var dist = global_position.distance_to(get_global_mouse_position())
		mouse_over = dist < 50
	
	if is_press and mouse_over:
		start_drag(input_pos)
	elif is_release and is_dragging:
		end_drag(input_pos)
	elif is_drag:
		drag_current_pos = input_pos

func start_drag(pos: Vector2):
	is_dragging = true
	drag_start_pos = pos
	drag_current_pos = pos
	
	# CRITICAL: Unfreeze package so it can receive impulse
	freeze = false
	print("PKG: Drag started - freeze=false")

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
		print("PKG: Drag below deadzone (", drag_distance, ")")
		return
	
	# Calculate impulse (speed is desired velocity, mass scaling happens in apply_central_impulse)
	var speed = clamp(drag_distance * IMPULSE_MULTIPLIER, MIN_SPEED, MAX_SPEED)
	var direction = drag_vector.normalized()
	var impulse_magnitude = speed * package_mass
	var impulse = direction * impulse_magnitude
	
	# Store flick data for hit validation
	last_flick_direction = direction
	last_flick_impulse = impulse_magnitude
	
	# LOG: Flick impulse
	print("═══════════════════════════════════════")
	print("🚀 FLICK APPLIED")
	print("  Package:", name, " ID:", get_instance_id())
	print("  Drag distance:", drag_distance)
	print("  Speed:", speed)
	print("  Direction:", direction)
	print("  Impulse magnitude:", impulse_magnitude)
	print("  Package mass:", package_mass)
	print("═══════════════════════════════════════")
	
	# Unfreeze and apply impulse
	freeze = false
	apply_central_impulse(impulse)
	has_been_flicked = true
	flick_time = Time.get_ticks_msec() / 1000.0  # Start timeout timer
	
	print("  ⏱️ Flick time recorded:", flick_time)
	
	# Wait a physics frame for impulse to take effect
	await get_tree().physics_frame
	
	# Verify velocity was applied
	print("📊 POST-FLICK VELOCITY CHECK:")
	print("  linear_velocity:", linear_velocity)
	print("  velocity magnitude:", linear_velocity.length())
	print("═══════════════════════════════════════")

# NOTE: This method is deprecated - TruckBay now calls GameManager.register_successful_load directly
# Kept for backward compatibility but should not be used for load counting
func try_score_hit(bay):
	print("PKG: try_score_hit called (DEPRECATED - should use direct GameManager call)")
	return

func _on_body_entered_miss_check(body):
	# M5 FIX: Emit miss immediately on ground/truck body hit
	if !has_been_flicked or resolved:
		return
	
	# If we hit ground or any static body (not the bay), it's a miss
	if body is StaticBody2D:
		print("PKG: Hit ground/wall - resolving miss")
		_resolve_miss()

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
