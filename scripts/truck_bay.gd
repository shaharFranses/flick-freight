extends Area2D

# Bay constants from design brief
const OPENING_WIDTH = 110.0
const TRAVEL_RANGE = 180.0
const PERIOD_START = 3.2
const PERIOD_END = 2.0
const LERP_TIME = 30.0

var start_time: float = 0.0
var center_x: float = 360.0  # Half of 720px dock width
var scored_packages: Array = []  # Track packages that have already scored

func _ready():
	start_time = Time.get_ticks_msec() / 1000.0
	position.x = center_x
	
	# Connect to detect packages entering
	body_entered.connect(_on_body_entered)

func _process(delta: float):
	var elapsed = (Time.get_ticks_msec() / 1000.0) - start_time
	var lerp_factor = clamp(elapsed / LERP_TIME, 0.0, 1.0)
	var current_period = lerp(PERIOD_START, PERIOD_END, lerp_factor)
	
	# Calculate sine wave position
	var angle = (elapsed / current_period) * TAU
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
		# Update DebugLabel
		var ui_manager = get_node_or_null("/root/Main/UIManager")
		if ui_manager and ui_manager.has_method("update_debug_label"):
			ui_manager.update_debug_label("❌ REJECT: Not a package")
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
		# Update DebugLabel
		var ui_manager = get_node_or_null("/root/Main/UIManager")
		if ui_manager and ui_manager.has_method("update_debug_label"):
			ui_manager.update_debug_label("⚠ REJECT: Not flicked")
		return
	
	# Mark as processed IMMEDIATELY
	scored_packages.append(package_root)
	
	# HIT VALIDATION: Accept if package was flicked and center is in opening
	var package_center = package_root.global_position
	var velocity = package_root.linear_velocity if package_root.has("linear_velocity") else Vector2.ZERO
	var bay_hitbox_scale = package_root.bay_hitbox_scale if package_root.get("bay_hitbox_scale") else 1.0
	var effective_width = 110.0 * bay_hitbox_scale
	
	# Check if package center is in opening
	var bay_left = global_position.x - effective_width / 2
	var bay_right = global_position.x + effective_width / 2
	var x_in_range = package_center.x >= bay_left and package_center.x <= bay_right
	
	# Get flick direction (use last_flick_direction if velocity is near zero)
	var direction_to_check = velocity
	if velocity.length() < 10 and package_root.has_method("get_last_flick_direction"):
		direction_to_check = package_root.get_last_flick_direction() * 100  # Scale for dot product
		print("  Using stored flick direction (velocity near zero)")
	
	# Check if direction is toward bay
	var to_bay = global_position - package_center
	var toward_truck = direction_to_check.dot(to_bay.normalized()) > 0
	
	# ACCEPT if: in opening AND (velocity toward truck OR was flicked in right direction)
	var hit_valid = x_in_range and toward_truck
	
	print("  Position check:")
	print("    Bay range: [%.1f, %.1f]" % [bay_left, bay_right])
	print("    Package X: %.1f" % package_center.x)
	print("    X in range:", x_in_range)
	print("  Direction check:")
	print("    Velocity:", velocity, " (mag: %.1f)" % velocity.length())
	print("    Toward truck:", toward_truck)
	print("  HIT VALID:", hit_valid)
	
	if !hit_valid:
		print("  ❌ REJECT: Invalid hit")
		scored_packages.erase(package_root)
		print("═══════════════════════════════════════")
		# Update DebugLabel
		var ui_manager = get_node_or_null("/root/Main/UIManager")
		if ui_manager and ui_manager.has_method("update_debug_label"):
			var reason = "X out" if !x_in_range else "Wrong dir"
			ui_manager.update_debug_label("❌ REJECT: %s (v=%.0f)" % [reason, velocity.length()])
		return
	
	print("  ✅ HIT VALID! Calling GameManager.register_successful_load")
	
	# Mark package as resolved BEFORE credit attempt
	if package_root.has("resolved"):
		package_root.resolved = true
	
	# Get package data
	var points = package_root.get_package_points() if package_root.has_method("get_package_points") else 1
	var credit_key = package_root.get_credit_key() if package_root.has_method("get_credit_key") else ""
	print("  Points:", points, " Credit key:", credit_key)
	print("═══════════════════════════════════════")
	
	# DIRECT CALL to GameManager with package ROOT
	var game_manager = get_node("/root/Main/GameManager")
	var credited = game_manager.register_successful_load(package_root, points)
	
	if credited:
		print("✅ Load credited - calling on_package_resolved from register")
		# Disable package physics and queue for deletion
		if package_root.has_method("set_physics_process"):
			package_root.set_physics_process(false)
		if package_root.has_method("set_process"):
			package_root.set_process(false)
		package_root.collision_layer = 0
		package_root.collision_mask = 0
		package_root.queue_free()
		# Note: on_package_resolved is called FROM GameManager.register_successful_load
	else:
		print("❌ Load rejected by GameManager")
		scored_packages.erase(package_root)
	
	# Clean up scored packages list after a delay
	get_tree().create_timer(1.0).timeout.connect(func(): 
		if package_root in scored_packages:
			scored_packages.erase(package_root)
	)

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
