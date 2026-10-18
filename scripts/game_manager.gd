extends Node

# DEBUG MODE: Set to false for shipping build
const DEBUG_MODE = false

# Game constants from design brief
const ROUND_TIME = 45.0
const WIN_QUOTA = 8
const SPAWN_DELAY = 0.35
const LERP_TIME = 30.0

# Package spawn weights
const EARLY_WEIGHTS = {"box": 0.50, "crate": 0.35, "barrel": 0.15}
const LATE_WEIGHTS = {"box": 0.30, "crate": 0.40, "barrel": 0.30}

# Package scenes
var package_scenes = {
	"box": preload("res://scenes/package_box.tscn"),
	"crate": preload("res://scenes/package_crate.tscn"),
	"barrel": preload("res://scenes/package_barrel.tscn")
}

# Game state
var time_remaining: float = ROUND_TIME
var loads_completed: int = 0
var current_score: int = 0
var streak: int = 0
var is_paused: bool = false
var tab_hidden_paused: bool = false  # Dedicated flag for tab visibility pause
var is_game_over: bool = false
var can_spawn: bool = true
var spawn_timer: float = 0.0

# CRITICAL: Track credited packages by instance_id to prevent double-counting
var credited_ids: Dictionary = {}

# NUCLEAR GUARD: Cooldown between any credits (prevent burst)
var score_cooldown_until: int = 0

# BUBBLE-SHOOTER SPAWN: One current + one preview
var current_package: RigidBody2D = null  # Only this is flickable
var next_preview: Node2D = null  # Display only visual
var next_type: String = ""  # ALWAYS stores the next package type
var is_advancing: bool = false  # Tween in progress

# Signals
signal score_changed(new_score: int)
signal loads_changed(loads: int, quota: int)
signal timer_changed(time: float)
signal game_won
signal game_lost
signal streak_changed(streak: int)

func _ready():
	# SELF-TEST: Verify credit system works (after frame delay, debug mode only)
	if DEBUG_MODE:
		await get_tree().process_frame
		run_self_test()
	
	spawn_package()

func run_self_test():
	print("═══════════════════════════════════════")
	print("🧪 SELF-TEST: Credit system with forced same key")
	
	# Create two dummy nodes with SAME forced credit_key
	var dummy1 = Node.new()
	dummy1.name = "TestDummy1"
	var dummy2 = Node.new()
	dummy2.name = "TestDummy2"
	
	# Mock get_credit_key to return SAME string for both
	var test_key = "test_forced_key_123"
	
	# Test state before
	var original_loads = loads_completed
	var original_size = credited_ids.size()
	
	print("  Initial state:")
	print("    loads_completed:", original_loads)
	print("    credited_ids.size:", original_size)
	
	# Test 1: First dummy with key "test"
	print("  Test 1: First call with key:", test_key)
	var success1 = test_register_credit(test_key, 1)
	print("    Result:", "SUCCESS" if success1 else "FAIL")
	print("    loads_completed:", loads_completed)
	print("    credited_ids.size:", credited_ids.size())
	
	# Test 2: Second dummy with SAME key "test"
	print("  Test 2: Second call with SAME key:", test_key)
	var success2 = test_register_credit(test_key, 1)
	print("    Result:", "SUCCESS (bad)" if success2 else "REJECTED (good)")
	print("    loads_completed:", loads_completed)
	print("    credited_ids.size:", credited_ids.size())
	
	# Verify
	var test1_ok = success1 and (loads_completed == original_loads + 1)
	var test2_ok = !success2 and (loads_completed == original_loads + 1)  # Still 1, not 2
	var dict_ok = credited_ids.size() == original_size + 1  # Only 1 entry added
	
	# Reset state
	loads_completed = original_loads
	credited_ids.clear()
	
	var all_pass = test1_ok and test2_ok and dict_ok
	
	var result_text = ""
	if all_pass:
		result_text = "✅ SELFTEST_OK loads=%d" % loads_completed
		print("✅ SELFTEST_OK: First credit succeeded, second rejected")
	else:
		result_text = "❌ SELFTEST_FAIL"
		print("❌ SELFTEST_FAIL:")
		print("  Test1 (first should succeed):", test1_ok, " (expected true)")
		print("  Test2 (same key should reject):", test2_ok, " (expected true)")
		print("  Dict check (only 1 entry):", dict_ok, " (expected true)")
	
	# Update debug label with self-test result
	await get_tree().process_frame
	var ui_manager = get_node_or_null("/root/Main/UIManager")
	if ui_manager and ui_manager.has_method("update_debug_label"):
		ui_manager.update_debug_label(result_text)
	
	print("═══════════════════════════════════════")
	
	dummy1.queue_free()
	dummy2.queue_free()

func test_register_credit(key: String, points: int) -> bool:
	# Simulate register_successful_load check
	if credited_ids.has(key):
		return false
	credited_ids[key] = true
	loads_completed += 1
	return true

func _process(delta: float):
	# FIRST CHECK: Tab hidden pause (highest priority)
	if tab_hidden_paused or is_paused or is_game_over:
		return
	
	# DEBUG: F1 key to test credit system (only in debug mode)
	if DEBUG_MODE and (Input.is_action_just_pressed("ui_select") or Input.is_key_pressed(KEY_F1)):
		debug_add_credit()
	
	# INVARIANT CHECK: Max 1 package in group at any time
	var packages_in_group = get_tree().get_nodes_in_group("packages")
	if packages_in_group.size() > 1:
		print("⚠️ INVARIANT VIOLATION: ", packages_in_group.size(), " packages in group!")
		for pkg in packages_in_group:
			print("  - ", pkg.name, " id:", pkg.get_instance_id())
	
	# Update timer
	time_remaining -= delta
	timer_changed.emit(time_remaining)
	
	# Check lose condition
	if time_remaining <= 0:
		time_remaining = 0
		timer_changed.emit(time_remaining)
		if loads_completed < WIN_QUOTA:
			game_over(false)
		return
	
	# Handle spawn timer
	if !can_spawn:
		spawn_timer -= delta
		if spawn_timer <= 0:
			can_spawn = true
			spawn_package()

func spawn_package():
	# Called at round start to initialize CURRENT + NEXT
	if current_package != null or is_advancing:
		return
	
	# ROUND START ONLY: Create first CURRENT + NEXT
	print("📦 ROUND START: Creating initial CURRENT + NEXT")
	
	# Roll types for both
	var current_type = select_random_type()
	next_type = select_random_type()
	
	# Create CURRENT package
	current_package = package_scenes[current_type].instantiate()
	get_tree().root.get_node("Main/World").add_child(current_package)
	current_package.position = Vector2(360, 1150)  # Throw slot
	current_package.freeze = true  # Start frozen
	
	print("  ✅ CURRENT created: type=", current_type, " id=", current_package.get_instance_id())
	
	# Generate NEXT preview visual
	generate_preview(next_type)
	
	print("  ✅ NEXT preview: type=", next_type)
	print("═══════════════════════════════════════")

func select_random_type() -> String:
	# Apply weights lerped by elapsed round time
	var elapsed = ROUND_TIME - time_remaining
	var lerp_factor = clamp(elapsed / LERP_TIME, 0.0, 1.0)
	
	var weights = {}
	for key in EARLY_WEIGHTS.keys():
		weights[key] = lerp(EARLY_WEIGHTS[key], LATE_WEIGHTS[key], lerp_factor)
	
	var rand_val = randf()
	var cumulative = 0.0
	var selected = "box"
	
	for type in ["box", "crate", "barrel"]:
		cumulative += weights[type]
		if rand_val <= cumulative:
			selected = type
			break
	
	return selected

func generate_preview(type: String):
	# Remove old preview if exists
	if next_preview != null and is_instance_valid(next_preview):
		next_preview.queue_free()
	
	# Store type for advance (CRITICAL: this is the source of truth)
	next_type = type
	
	# Create NEXT preview BIGGER (48-64px min for portal readability)
	# Position: Left of throw slot
	next_preview = Node2D.new()
	next_preview.name = "NextPreview"
	next_preview.position = Vector2(280, 1150)  # Left of throw slot
	next_preview.scale = Vector2(0.8, 0.8)  # 80% scale (was 60%)
	next_preview.modulate = Color(0.75, 0.75, 0.75, 1.0)  # 75% brightness (was 70%)
	
	# Add visual based on type (larger colored rect + label)
	var visual = ColorRect.new()
	if type == "box":
		visual.size = Vector2(48, 48)
		visual.color = Color(0.961, 0.773, 0.259, 1)  # Amber
		visual.position = Vector2(-24, -24)
	elif type == "crate":
		visual.size = Vector2(64, 64)
		visual.color = Color(0.769, 0.478, 0.227, 1)  # Brown
		visual.position = Vector2(-32, -32)
	else:  # barrel
		visual.size = Vector2(56, 72)
		visual.color = Color(0.227, 0.549, 0.769, 1)  # Blue
		visual.position = Vector2(-28, -36)
	
	next_preview.add_child(visual)
	
	# Add label (bigger font)
	var label = Label.new()
	label.text = type.to_upper()
	label.add_theme_font_size_override("font_size", 18)  # Was 16
	label.position = Vector2(-20, -10)
	next_preview.add_child(label)
	
	# Add "NEXT" caption above (bigger)
	var caption = Label.new()
	caption.text = "NEXT"
	caption.add_theme_font_size_override("font_size", 16)  # Was 14
	caption.position = Vector2(-15, -55)  # Adjusted for bigger preview
	next_preview.add_child(caption)
	
	get_tree().root.get_node("Main/World").add_child(next_preview)
	
	print("  Generated NEXT preview:", type, " (80% scale, portal readable)")

func on_package_resolved():
	# CRITICAL: Called when current package lands (hit OR miss)
	# MUST advance NEXT → CURRENT with 0.3s tween
	
	print("═══════════════════════════════════════")
	print("🚨 RESOLVE CALLED")
	print("═══════════════════════════════════════")
	
	# Use call_deferred to ensure this runs even if caller is freed
	if !is_advancing:
		is_advancing = true
		call_deferred("_do_advance_async")
	else:
		print("⚠️ RESOLVE SKIPPED: Already advancing")

func _do_advance_async():
	# Async advance function that runs via deferred call
	
	print("═══════════════════════════════════════")
	print("🔄 ADVANCE START")
	
	# Clear current package reference
	if current_package != null and is_instance_valid(current_package):
		current_package.queue_free()
	current_package = null
	
	# Remove preview visual
	if next_preview != null and is_instance_valid(next_preview):
		next_preview.queue_free()
		next_preview = null
	
	# Wait 0.3s tween
	print("  ⏳ Waiting 0.3s for tween...")
	await get_tree().create_timer(0.3).timeout
	
	# Create new CURRENT from next_type
	if next_type == "":
		print("  ❌ ERROR: next_type is empty!")
		is_advancing = false
		return
	
	print("  📦 Creating new CURRENT: type =", next_type)
	current_package = package_scenes[next_type].instantiate()
	get_tree().root.get_node("Main/World").add_child(current_package)
	current_package.position = Vector2(360, 1150)  # Throw slot position
	current_package.freeze = true  # Start frozen for stability, unfreezed on start_drag
	
	print("═══════════════════════════════════════")
	print("✅ NEW CURRENT SPAWNED")
	print("  Type:", next_type)
	print("  ID:", current_package.get_instance_id())
	print("  freeze:", current_package.freeze, " (true = stable until drag)")
	print("  position:", current_package.position)
	print("═══════════════════════════════════════")
	
	# Roll NEW next_type + rebuild preview
	var new_next = select_random_type()
	generate_preview(new_next)
	
	# Unlock input
	is_advancing = false
	
	# VERIFICATION LOGGING
	var packages_in_group = get_tree().get_nodes_in_group("packages")
	print("  ✅ ADVANCE COMPLETE:")
	print("    New CURRENT path:", current_package.get_path())
	print("    New CURRENT ID:", current_package.get_instance_id())
	print("    Packages in group:", packages_in_group.size(), " (must be 1)")
	print("    is_advancing:", is_advancing, " (must be false)")
	print("    next_type:", next_type)
	print("═══════════════════════════════════════")

# DIRECT CREDIT PATH - No signals for load counting
# Called directly by TruckBay when valid hit occurs
# Returns true if credit accepted, false if rejected
func register_successful_load(package: Node, base_points: int) -> bool:
	var now = Time.get_ticks_msec()
	
	# NUCLEAR GUARD: Cooldown between credits (one flick cannot credit 8x in 400ms)
	if now < score_cooldown_until:
		print("═══════════════════════════════════════")
		print("⛔ COOLDOWN GUARD: Too soon after last credit")
		print("  Now:", now, " Cooldown until:", score_cooldown_until)
		print("  Wait:", score_cooldown_until - now, "ms")
		print("═══════════════════════════════════════")
		return false
	
	var credit_key = package.get_credit_key() if package.has_method("get_credit_key") else ""
	var id = package.get_instance_id()
	
	# CRITICAL: Use credit_key if available, fallback to instance_id
	var lookup_key = credit_key if credit_key != "" else str(id)
	
	print("═══════════════════════════════════════")
	print("📋 REGISTER LOAD ATTEMPT #", credited_ids.size() + 1)
	print("  Package:", package.name)
	print("  Instance ID:", id)
	print("  Credit key:", credit_key)
	print("  LOOKUP KEY:", lookup_key, " ← EXACT KEY USED")
	print("  Base points:", base_points)
	print("  Current loads:", loads_completed)
	print("  credited_ids size:", credited_ids.size())
	print("  credited_ids keys:", credited_ids.keys())
	print("  Already credited?", credited_ids.has(lookup_key))
	print("═══════════════════════════════════════")
	
	# GUARD: Already credited this exact package
	if credited_ids.has(lookup_key):
		print("❌ REJECTED: Key", lookup_key, "already in credited_ids")
		print("  This is call #", credited_ids.size() + 1, " - should be 1 per package")
		return false
	
	# GUARD: At quota
	if loads_completed >= WIN_QUOTA:
		print("❌ REJECTED: Already at quota (", WIN_QUOTA, ")")
		return false
	
	# GUARD: Game over
	if is_game_over:
		print("❌ REJECTED: Game already over")
		return false
	
	# ACCEPT CREDIT - Mark as credited FIRST
	credited_ids[lookup_key] = true
	print("✅ CREDITED: Key", lookup_key, "added to dictionary")
	print("  credited_ids now has", credited_ids.size(), " entries")
	
	# SET COOLDOWN: No more credits for 400ms
	score_cooldown_until = now + 400
	print("⏱ COOLDOWN SET: Until", score_cooldown_until, " (+400ms)")
	
	# Increment loads EXACTLY ONCE (capped at quota)
	var old_loads = loads_completed
	loads_completed = mini(loads_completed + 1, WIN_QUOTA)
	
	# Streak increments +1 ONCE per successful load
	var old_streak = streak
	streak += 1
	
	# Score calculation per design: base_points + (streak-1) bonus
	var total_points = base_points + (streak - 1)
	current_score += total_points
	
	print("  Loads:", old_loads, "→", loads_completed, " (+1)")
	print("  Streak:", old_streak, "→", streak, " (+1)")
	print("  Score: +", total_points, " = ", current_score)
	print("═══════════════════════════════════════")
	
	# Emit UI update signals ONCE
	score_changed.emit(current_score)
	loads_changed.emit(loads_completed, WIN_QUOTA)
	streak_changed.emit(streak)
	
	# Update debug label (if exists)
	var debug_label = get_node_or_null("/root/Main/UIManager/UI/DebugLabel")
	if debug_label:
		debug_label.text = "LastCredit: +1 (loads=%d) key=%s" % [loads_completed, lookup_key.substr(0, 10)]
	
	# Check win condition
	if loads_completed >= WIN_QUOTA:
		print("🏆 WIN: Quota reached - calling game_over(true)")
		game_over(true)
		return true
	
	# Package resolved - advance conveyor
	print("✅ LOAD SUCCESSFUL - Calling on_package_resolved()")
	on_package_resolved()
	
	return true

func _on_package_missed():
	# Reset streak on miss
	streak = 0
	streak_changed.emit(streak)
	print("❌ MISS: Streak reset to 0")
	
	# Package resolved - advance conveyor
	print("✅ MISS REGISTERED - Calling on_package_resolved()")
	on_package_resolved()

func game_over(won: bool):
	is_game_over = true
	if won:
		game_won.emit()
	else:
		game_lost.emit()

func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused

func restart_game():
	get_tree().reload_current_scene()

# DEBUG FUNCTION: Test credit system with F1 key
func debug_add_credit():
	print("═══════════════════════════════════════")
	print("🔧 DEBUG +1 LOAD (F1 pressed)")
	
	var package_to_use = null
	
	# PRIORITY: Use CURRENT package if available
	if current_package != null and is_instance_valid(current_package):
		package_to_use = current_package
		print("  Using CURRENT package:", package_to_use.name)
	else:
		# No current package, create dummy
		var dummy = Node.new()
		dummy.name = "DebugDummy"
		dummy.set("credit_key", "debug_dummy_" + str(Time.get_ticks_msec()))
		get_tree().root.add_child(dummy)
		package_to_use = dummy
		print("  No CURRENT package, created dummy")
	
	# Get credit key
	var test_key = ""
	if package_to_use.has_method("get_credit_key"):
		test_key = package_to_use.get_credit_key()
	elif package_to_use.get("credit_key"):
		test_key = package_to_use.get("credit_key")
	else:
		test_key = "debug_" + str(package_to_use.get_instance_id())
	
	print("  Credit key:", test_key)
	print("  Loads before:", loads_completed)
	
	# Call register_successful_load
	var old_loads = loads_completed
	var success = register_successful_load(package_to_use, 1)
	
	print("  Success:", success)
	print("  Loads after:", loads_completed)
	
	# Update DebugLabel
	var ui_manager = get_node_or_null("/root/Main/UIManager")
	var result_text = ""
	if success and loads_completed == old_loads + 1:
		result_text = "✅ DEBUG +1 OK: loads=%d" % loads_completed
		print("✅ DEBUG CREDIT OK: loads incremented +1")
	elif !success and loads_completed == old_loads:
		result_text = "⚠ REJECTED: loads=%d (same key or quota)" % loads_completed
		print("⚠ DEBUG CREDIT REJECTED: Same package or at quota")
	else:
		result_text = "❌ ERROR: loads=%d" % loads_completed
		print("❌ DEBUG CREDIT ERROR: Unexpected state")
	
	if ui_manager and ui_manager.has_method("update_debug_label"):
		ui_manager.update_debug_label(result_text)
	
	print("═══════════════════════════════════════")
	
	# Clean up dummy if created
	if package_to_use != current_package and is_instance_valid(package_to_use):
		package_to_use.queue_free()
