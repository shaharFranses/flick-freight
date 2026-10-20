extends Area2D

# Bay constants from design brief
const OPENING_WIDTH = 110.0
const TRAVEL_RANGE = 180.0  # Design spec: ±180px
const PERIOD_START = 3.2
const PERIOD_END = 2.0
const LERP_TIME = 30.0

var start_time: float = 0.0
var center_x: float = 360.0  # Half of 720px dock width
var scored_packages: Array = []  # Track packages that have already scored
var speed_multiplier: float = 1.0  # QA mode: 0.25 for slower bay
var round_start_time: float = 0.0  # Track round start for speed ramp

func _ready():
	start_time = Time.get_ticks_msec() / 1000.0
	round_start_time = start_time
	position.x = center_x
	
	# Connect to detect packages entering
	body_entered.connect(_on_body_entered)

func reset_position():
	"""Reset truck to center position and restart speed ramp"""
	position.x = center_x
	start_time = Time.get_ticks_msec() / 1000.0
	round_start_time = start_time
	scored_packages.clear()

func set_speed_multiplier(multiplier: float):
	"""Set bay speed multiplier (QA mode: 0.25 for 4x slower)"""
	speed_multiplier = multiplier


func _process(delta: float):
	var elapsed = (Time.get_ticks_msec() / 1000.0) - start_time
	
	# ITEM 1: Speed ramp from 0.6 to 1.0 over first 7 seconds of each round
	var round_elapsed = (Time.get_ticks_msec() / 1000.0) - round_start_time
	var ramp_duration = 7.0
	var ramp_multiplier = 1.0
	if round_elapsed < ramp_duration:
		# Ramp from 0.6 to 1.0 over ramp_duration seconds
		ramp_multiplier = lerp(0.6, 1.0, round_elapsed / ramp_duration)
	
	# Compose ramp with QA mode: final_multiplier = speed_multiplier * ramp_multiplier
	# QA mode (0.25) stays 0.25x of the ramped speed
	var final_multiplier = speed_multiplier * ramp_multiplier
	
	# Apply final multiplier to elapsed time
	var adjusted_elapsed = elapsed * final_multiplier
	
	var lerp_factor = clamp(adjusted_elapsed / LERP_TIME, 0.0, 1.0)
	var current_period = lerp(PERIOD_START, PERIOD_END, lerp_factor)
	
	# Calculate sine wave position
	var angle = (adjusted_elapsed / current_period) * TAU
	var offset = sin(angle) * TRAVEL_RANGE
	
	position.x = center_x + offset

func _on_body_entered(body: Node2D):
	# LOG: Package count in group (detect spawn bugs)
	var packages_in_group = get_tree().get_nodes_in_group("packages")
	var package_count = packages_in_group.size()
	
	print("═══════════════════════════════════════")
	print("🔍 BODY_ENTERED DEBUG")
	print("  📦 PACKAGES IN GROUP:", package_count, " ← Should be 1 during first flick")
	if package_count > 1:
		print("  ⚠️ WARNING: Multiple packages exist!")
		for pkg in packages_in_group:
			print("    - ", pkg.name, " id:", pkg.get_instance_id())
	print("  Body name:", body.name)
	print("  Body class:", body.get_class())
	print("  Body path:", body.get_path())
	print("  Body instance_id:", body.get_instance_id())
	
	# RELAXED PACKAGE RECOGNITION
	# Accept if:
	# 1) Body is in packages group (ideal)
	# 2) Body is RigidBody2D with package methods (fallback)
	# 3) Parent/owner is in packages group (child collision)
	
	var package_root = null
	
	# Try: body itself
	if body.is_in_group("packages"):
		package_root = body
		print("  ✅ Package root: body in group")
	elif body is RigidBody2D and body.has_method("get_credit_key") and body.has_method("get_package_points"):
		package_root = body
		print("  ✅ Package root: body is RigidBody2D with methods")
	
	# Try: parent
	if package_root == null and body.get_parent():
		var parent = body.get_parent()
		if parent.is_in_group("packages"):
			package_root = parent
			print("  ✅ Package root: parent in group")
		elif parent is RigidBody2D and parent.has_method("get_credit_key"):
			package_root = parent
			print("  ✅ Package root: parent is RigidBody2D with methods")
	
	# Try: owner
	if package_root == null and body.owner:
		if body.owner.is_in_group("packages"):
			package_root = body.owner
			print("  ✅ Package root: owner in group")
		elif body.owner is RigidBody2D and body.owner.has_method("get_credit_key"):
			package_root = body.owner
			print("  ✅ Package root: owner is RigidBody2D with methods")
	
	if package_root == null:
		print("  ❌ REJECT: Could not resolve package root")
		print("  → Body not in group, not RigidBody2D, no valid parent/owner")
		print("═══════════════════════════════════════")
		return
	
	print("  ✅ Resolved package root:", package_root.name)
	print("  Root instance_id:", package_root.get_instance_id())
	
	# Check if already processed
	if package_root in scored_packages:
		print("  ⚠ REJECT: Package root already in scored_packages list")
		print("═══════════════════════════════════════")
		return
	
	# Check if package has been flicked
	if !package_root.has_method("is_package_flicked") or !package_root.is_package_flicked():
		print("  ⚠ REJECT: Package not flicked yet")
		print("═══════════════════════════════════════")
		return
	
	# Mark as processed IMMEDIATELY
	scored_packages.append(package_root)
	
	# HIT VALIDATION: Use global coordinates for both package and bay
	var package_center = package_root.global_position
	var velocity = package_root.linear_velocity if package_root is RigidBody2D else Vector2.ZERO
	var bay_hitbox_scale = package_root.bay_hitbox_scale if package_root.get("bay_hitbox_scale") != null else 1.0
	var effective_width = OPENING_WIDTH * bay_hitbox_scale
	
	# Bay opening rect in GLOBAL space
	var bay_global_x = global_position.x
	var bay_left = bay_global_x - effective_width / 2
	var bay_right = bay_global_x + effective_width / 2
	
	# Check if package center is within bay opening (X-range)
	var x_in_range = package_center.x >= bay_left and package_center.x <= bay_right
	
	# Check velocity (moving with reasonable speed, not drifting)
	var vel_ok = velocity.length() > 200
	
	print("BAY: Hit check - x_range:%s vel_ok:%s width:%.1f" % [x_in_range, vel_ok, effective_width])
	print("  Package global x: %.1f, Bay global x: %.1f (range %.1f to %.1f)" % [package_center.x, bay_global_x, bay_left, bay_right])
	print("  Velocity: %.1f px/s" % velocity.length())
	
	# STRICT: Both checks must pass
	if !x_in_range or !vel_ok:
		if !x_in_range:
			print("  ❌ REJECT: Package outside bay opening (x=%.1f not in [%.1f, %.1f])" % [package_center.x, bay_left, bay_right])
		if !vel_ok:
			print("  ❌ REJECT: Velocity too low (%.1f px/s < 200 px/s)" % velocity.length())
		scored_packages.erase(package_root)
		print("═══════════════════════════════════════")
		return
	
	print("  ✅ HIT VALID! Package in range with good velocity")
	print("  ✅ Calling GameManager.register_successful_load")
	
	# Get package data
	var points = package_root.get_package_points() if package_root.has_method("get_package_points") else 1
	var credit_key = package_root.get_credit_key() if package_root.has_method("get_credit_key") else ""
	print("  Points:", points, " Credit key:", credit_key)
	print("═══════════════════════════════════════")
	
	# DIRECT CALL to GameManager with package ROOT
	var game_manager = get_node("/root/Main/GameManager")
	var credited = game_manager.register_successful_load(package_root, points)
	
	if credited:
		print("✅ Load credited - disabling package")
		# Disable package physics and queue for deletion
		if package_root.has_method("set_physics_process"):
			package_root.set_physics_process(false)
		if package_root.has_method("set_process"):
			package_root.set_process(false)
		package_root.collision_layer = 0
		package_root.collision_mask = 0
		package_root.queue_free()
		# Note: Package stays in scored_packages list but won't re-enter (queued for deletion)
	else:
		print("❌ Load rejected by GameManager")
		scored_packages.erase(package_root)

func is_hit_valid(package_center: Vector2, velocity: Vector2, effective_width: float) -> bool:
	# Check if package center is within opening width (scaled by package's bay hitbox scale)
	var bay_left = global_position.x - effective_width / 2
	var bay_right = global_position.x + effective_width / 2
	
	var x_in_range = package_center.x >= bay_left and package_center.x <= bay_right
	
	# Truck is at y=150, packages spawn at y=1150
	# Toward-truck is UPWARD (negative Y)
	# Check if velocity is mostly toward truck (dot with vector toward bay)
	var to_bay = global_position - package_center
	var toward_truck = velocity.dot(to_bay.normalized())
	var velocity_ok = toward_truck > 0
	
	print("BAY: Hit check - x_range:", x_in_range, " vel_ok:", velocity_ok, " width:", effective_width)
	
	return x_in_range and velocity_ok
