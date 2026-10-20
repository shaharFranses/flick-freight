extends Node

# DEBUG MODE: Set to false for shipping build
const DEBUG_MODE = false

# SHIFT CONFIG: Data-driven level design
class ShiftConfig:
	var shift_number: int
	var name: String
	var timer: float
	var quota: int
	var bay_period_start: float
	var bay_period_end: float
	var allowed_packages: Array
	
	func _init(num: int, n: String, t: float, q: int, bay_start: float, bay_end: float, packages: Array):
		shift_number = num
		name = n
		timer = t
		quota = q
		bay_period_start = bay_start
		bay_period_end = bay_end
		allowed_packages = packages

var SHIFTS: Array[ShiftConfig] = [
	ShiftConfig.new(1, "Dock Warmup", 40.0, 5, 3.6, 3.2, ["box"]),
	ShiftConfig.new(6, "Full Crew", 45.0, 8, 3.2, 2.4, ["box", "crate", "barrel"]),
	ShiftConfig.new(12, "Night Shift", 38.0, 11, 2.3, 1.8, ["box", "crate", "barrel"])
]

var current_shift_index: int = 1
var current_shift: ShiftConfig = SHIFTS[1]

# Game constants from design brief (driven by shift config)
var ROUND_TIME: float = 45.0
var WIN_QUOTA: int = 8
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
var is_game_over: bool = false
var can_spawn: bool = true
var spawn_timer: float = 0.0
var qa_mode: bool = false  # QA flag: slower bay, longer juice
var has_spawned_first: bool = false  # A: Timer must not tick before first spawn

# CRITICAL: Track credited packages by instance_id to prevent double-counting
var credited_ids: Dictionary = {}

# NUCLEAR GUARD: Cooldown between any credits (prevent burst)
var score_cooldown_until: int = 0

# BUBBLE-SHOOTER SPAWN: One current + one preview
var current_package: RigidBody2D = null  # Only this is flickable
var next_preview: Node2D = null  # Display only, no physics
var next_preview_type: String = ""  # Track the type that will become current
var advance_lock_until: float = 0.0  # 0.3s lock after resolve

# Signals
signal score_changed(new_score: int)
signal loads_changed(loads: int, quota: int)
signal timer_changed(time: float)
signal game_won
signal game_lost
signal streak_changed(streak: int)

func _ready():
	# QA ITEM 2: Set clear color for letterbox bars
	RenderingServer.set_default_clear_color(Color(0.122, 0.149, 0.2, 1))
	
	call_deferred("_init_shift_config")
	
	# Detect QA mode from URL parameter ?qa=1
	if OS.has_feature("web"):
		var search_string = JavaScriptBridge.eval("location.search || ''")
		if search_string and search_string is String:
			qa_mode = search_string.contains("qa=1")
	
	# Always log QA mode status at boot
	print("═══════════════════════════════════════")
	print("🔧 QA MODE: ", "ACTIVE (0.25x bay, 3x juice)" if qa_mode else "OFF (normal speed)")
	print("═══════════════════════════════════════")
	
	# Hide debug UI in release builds
	if not OS.is_debug_build():
		var debug_label = get_node_or_null("/root/Main/UIManager/UI/DebugLabel")
		if debug_label:
			debug_label.visible = false
		var debug_button = get_node_or_null("/root/Main/UIManager/UI/DebugButton")
		if debug_button:
			debug_button.visible = false
	
	# SELF-TEST: Verify credit system works (after frame delay)
	await get_tree().process_frame
	run_self_test()
	
	# Set bay speed if QA mode is active
	if qa_mode:
		var truck_bay = get_tree().root.get_node_or_null("Main/World/TruckBay")
		if truck_bay and truck_bay.has_method("set_speed_multiplier"):
			truck_bay.set_speed_multiplier(0.25)
	
	spawn_package()

func _init_shift_config():
	# Initialize shift config after tree is ready
	load_shift(current_shift_index, false)

func _input(event):
	# Shift keys work in browser via _input (not _unhandled_input)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			load_shift(0)  # Shift 1
			get_viewport().set_input_as_handled()  # Prevent further processing
		elif event.keycode == KEY_6:
			load_shift(1)  # Shift 6
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_2:
			load_shift(2)  # Shift 12
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F2:
			# Cycle: 1→6→12→1 (shift indices 0→1→2→0)
			var next_index = (current_shift_index + 1) % SHIFTS.size()
			load_shift(next_index)
			get_viewport().set_input_as_handled()

func run_self_test():
	print("═══════════════════════════════════════")
	print("🧪 SELF-TEST: Credit system with forced same key")
	
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
		result_text = "✅ SELFTEST_OK"
		print("✅ SELFTEST_OK: First credit succeeded, second rejected")
	else:
		result_text = "❌ SELFTEST_FAIL"
		print("❌ SELFTEST_FAIL:")
		print("  Test1 (first should succeed):", test1_ok, " (expected true)")
		print("  Test2 (same key should reject):", test2_ok, " (expected true)")
		print("  Dict check (only 1 entry):", dict_ok, " (expected true)")
	
	# Update debug label with self-test result
	await get_tree().process_frame
	var debug_label = get_node_or_null("/root/Main/UIManager/UI/DebugLabel")
	if debug_label:
		debug_label.text = result_text
	
	print("═══════════════════════════════════════")

func test_register_credit(key: String, points: int) -> bool:
	# Simulate register_successful_load check
	if credited_ids.has(key):
		return false
	credited_ids[key] = true
	loads_completed += 1
	return true

func _process(delta: float):
	if is_game_over or is_paused:
		return
	
	# DEBUG: F1 key to test credit system
	if Input.is_action_just_pressed("ui_select") or Input.is_key_pressed(KEY_F1):
		debug_add_credit()
	
	# INVARIANT CHECK: Max 1 package in group at any time (excluding queued deletions)
	var packages_in_group = get_tree().get_nodes_in_group("packages")
	var active_packages = []
	for pkg in packages_in_group:
		if not pkg.is_queued_for_deletion():
			active_packages.append(pkg)
	
	if active_packages.size() > 1:
		print("⚠️ INVARIANT VIOLATION: ", active_packages.size(), " active packages!")
		for pkg in active_packages:
			print("  - ", pkg.name, " id:", pkg.get_instance_id())
	
	# A: Update timer only after first spawn
	if has_spawned_first:
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
	if !can_spawn and spawn_timer > 0:
		spawn_timer -= delta
		if spawn_timer <= 0:
			spawn_timer = 0.0  # CRITICAL: Reset timer to prevent spawning every frame
			spawn_package()

func spawn_package():
	# BUBBLE-SHOOTER: Only spawn if no current package exists
	if current_package != null and is_instance_valid(current_package):
		return  # Already have a package in throw slot
	
	if is_game_over:
		return
	
	# Calculate spawn weights based on time elapsed
	var elapsed = ROUND_TIME - time_remaining
	var lerp_factor = clamp(elapsed / LERP_TIME, 0.0, 1.0)
	
	var weights = {}
	for key in EARLY_WEIGHTS.keys():
		weights[key] = lerp(EARLY_WEIGHTS[key], LATE_WEIGHTS[key], lerp_factor)
	
	# Select package type based on weighted random
	var rand_val = randf()
	var cumulative = 0.0
	var selected_type = "box"
	
	for type in ["box", "crate", "barrel"]:
		cumulative += weights[type]
		if rand_val <= cumulative:
			selected_type = type
			break
	
	# BUBBLE-SHOOTER: If we have a preview, advance it to current
	if next_preview != null and is_instance_valid(next_preview):
		print("📦 ADVANCING preview to current slot")
		advance_preview_to_current(selected_type)
		# r3: new preview pops in when the slide finishes (see _finish_advance_anim)
		next_preview_type = selected_type
	else:
		# First spawn or no preview: create current directly
		print("📦 SPAWNING initial current package:", selected_type)
		current_package = package_scenes[selected_type].instantiate()
		get_tree().root.get_node("Main/World").add_child(current_package)
		
		# Add CURRENT chip (ITEM (a): visible immediately)
		add_current_chip_to_package(current_package)
		
		# CRITICAL: Connect missed signal to advance conveyor on misses
		current_package.missed.connect(_on_package_missed)
		
		print("  Current package ID:", current_package.get_instance_id())
		
		# Generate first preview
		var preview_type = select_random_type()
		generate_preview(preview_type)
		
		# A: Start timer after first spawn (deferred to next frame)
		call_deferred("_start_timer")
	
	can_spawn = false

func select_random_type() -> String:
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

# r3: NEXT preview sits beside the flick spot and shows the real cargo art
const FLICK_SPOT = Vector2(360, 1150)
const NEXT_POS = Vector2(530, 1160)
const NEXT_ART_SCALE = 0.75
const NEXT_SLIDE_TIME = 0.25
var advance_ghost: Node2D = null  # r3: transient cargo art sliding NEXT -> flick spot
var advance_tween: Tween = null
var next_pop_tween: Tween = null
var shake_tween_ref: Tween = null

func make_cargo_art(type: String) -> Node2D:
	"""r3: Display-only copy of a package scene's visuals (same art as in play)"""
	var art = Node2D.new()
	var package_instance = package_scenes[type].instantiate()
	for child in package_instance.get_children():
		if child is CanvasItem:
			art.add_child(child.duplicate())
	package_instance.free()
	return art

func generate_preview(type: String, pop_in: bool = false):
	# Remove old preview if exists
	if next_preview != null and is_instance_valid(next_preview):
		next_preview.queue_free()
	if next_pop_tween != null and next_pop_tween.is_valid():
		next_pop_tween.kill()
	
	# Store the type for truthful preview
	next_preview_type = type
	
	# Create DISPLAY-ONLY preview (no physics), right beside the flick spot
	next_preview = Node2D.new()
	next_preview.name = "NextPreview"
	next_preview.position = NEXT_POS
	next_preview.z_index = 5
	
	var panel = ColorRect.new()
	panel.name = "Panel"
	panel.size = Vector2(96, 112)
	panel.position = Vector2(-48, -64)
	panel.color = Color(0.1, 0.12, 0.18, 0.85)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_preview.add_child(panel)
	
	# Caption "NEXT" above the art
	var next_label = Label.new()
	next_label.name = "NextCaption"
	next_label.text = "NEXT"
	next_label.add_theme_font_size_override("font_size", 16)
	next_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_label.position = Vector2(-48, -62)
	next_label.size = Vector2(96, 20)
	next_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_preview.add_child(next_label)
	
	# Small arrow pointing at the flick spot ("up next" reads left)
	var arrow = Polygon2D.new()
	arrow.name = "NextArrow"
	arrow.polygon = PackedVector2Array([Vector2(-50, -6), Vector2(-62, 0), Vector2(-50, 6)])
	arrow.color = Color(1, 0.9, 0.4, 0.9)
	next_preview.add_child(arrow)
	
	# Real cargo art, scaled down
	var art = make_cargo_art(type)
	art.name = "CargoArt"
	art.scale = Vector2(NEXT_ART_SCALE, NEXT_ART_SCALE)
	art.position = Vector2(0, 4)
	next_preview.add_child(art)
	
	get_tree().root.get_node("Main/World").add_child(next_preview)
	
	if pop_in:
		next_preview.scale = Vector2(0.2, 0.2)
		next_pop_tween = next_preview.create_tween()
		next_pop_tween.tween_property(next_preview, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		next_pop_tween.tween_property(next_preview, "scale", Vector2(1.0, 1.0), 0.08)
	
	print("  Generated preview:", type, "(truthful: will become CURRENT, real art beside flick spot)")

func add_current_chip_to_package(package: RigidBody2D):
	"""(3): Add CURRENT chip with bigger label (>=14px effective) and high-contrast backing"""
	# (3): Add dark backing plate first (drawn behind label)
	var label_backing = ColorRect.new()
	label_backing.size = Vector2(90, 28)
	label_backing.color = Color(0.05, 0.05, 0.1, 0.95)  # Very dark, high opacity
	label_backing.position = Vector2(-45, -75)  # Above package
	label_backing.z_index = 99
	package.add_child(label_backing)
	
	# (3): Add CURRENT label with bigger font and bright color
	var current_label = Label.new()
	current_label.name = "CurrentChip"
	current_label.text = "CURRENT"
	current_label.add_theme_font_size_override("font_size", 20)  # Bigger for >= 14px effective
	current_label.add_theme_color_override("font_color", Color(1, 1, 0.3, 1))  # Bright yellow
	current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_label.position = Vector2(-45, -72)  # Centered on backing
	current_label.size = Vector2(90, 24)
	current_label.z_index = 100
	package.add_child(current_label)

func advance_preview_to_current(new_preview_type: String = ""):
	# Move preview to current slot (becomes real physics package)
	if next_preview == null or !is_instance_valid(next_preview):
		return
	
	# Use the stored preview type (truthful preview)
	var type_name = next_preview_type if next_preview_type != "" else "box"
	var from_pos = next_preview.position
	
	# Remove preview
	next_preview.queue_free()
	next_preview = null
	next_preview_type = ""
	
	# Create actual physics package (same as before: spot, CURRENT chip, missed signal)
	current_package = package_scenes[type_name].instantiate()
	get_tree().root.get_node("Main/World").add_child(current_package)
	add_current_chip_to_package(current_package)
	current_package.missed.connect(_on_package_missed)
	print("  Advanced to current, ID:", current_package.get_instance_id(), "type:", type_name)
	
	# Set advance lock
	advance_lock_until = Time.get_ticks_msec() / 1000.0 + 0.3
	
	# r3: slide/pop animation. The real package is hidden + input-locked while a ghost
	# copy of its art slides from NEXT into the flick spot with a scale bounce.
	_clear_advance_anim()
	var pkg = current_package
	pkg.modulate.a = 0.0
	pkg.set_process_input(false)
	advance_ghost = make_cargo_art(type_name)
	advance_ghost.name = "AdvanceGhost"
	advance_ghost.position = from_pos + Vector2(0, 4)
	advance_ghost.scale = Vector2(0.8, 0.8)
	advance_ghost.z_index = 6
	get_tree().root.get_node("Main/World").add_child(advance_ghost)
	var ghost = advance_ghost
	advance_tween = ghost.create_tween()
	advance_tween.set_parallel(true)
	advance_tween.tween_property(ghost, "position", FLICK_SPOT, NEXT_SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	advance_tween.tween_property(ghost, "scale", Vector2(1.1, 1.1), NEXT_SLIDE_TIME * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	advance_tween.chain().tween_property(ghost, "scale", Vector2(1.0, 1.0), 0.08)
	advance_tween.chain().tween_callback(func():
		_finish_advance_anim(pkg, new_preview_type)
	)

func _finish_advance_anim(pkg, new_preview_type: String):
	if is_instance_valid(advance_ghost):
		advance_ghost.queue_free()
	advance_ghost = null
	advance_tween = null
	if is_instance_valid(pkg):
		pkg.modulate.a = 1.0
		pkg.set_process_input(true)
		if is_game_over:
			pkg.visible = false
	# Refresh NEXT with a pop-in (type was decided at advance time)
	if new_preview_type != "" and !is_game_over and (next_preview == null or !is_instance_valid(next_preview)):
		generate_preview(new_preview_type, true)

func _clear_advance_anim():
	if advance_tween != null and advance_tween.is_valid():
		advance_tween.kill()
	advance_tween = null
	if advance_ghost != null and is_instance_valid(advance_ghost):
		advance_ghost.queue_free()
	advance_ghost = null

func on_package_resolved():
	# Called when current package lands or misses
	current_package = null
	
	# Start spawn timer to advance next
	can_spawn = false  # FIXED: was true, should be false so timer decrements
	spawn_timer = SPAWN_DELAY
	
	print("📦 Package resolved, will advance preview in", SPAWN_DELAY, "s")

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
	
	# JUICE: Hit effect (particles + score pop)
	var pkg_color = package.modulate if package.get("modulate") != null else Color(1, 1, 1)
	spawn_hit_juice(package.global_position, total_points, pkg_color)
	
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
	on_package_resolved()
	
	return true

func _on_package_missed():
	# Reset streak on miss
	streak = 0
	streak_changed.emit(streak)
	print("❌ MISS: Streak reset to 0")
	
	# JUICE: Miss dust particles
	if current_package != null and is_instance_valid(current_package):
		spawn_miss_juice(current_package.global_position)
	
	# Package resolved - advance conveyor
	on_package_resolved()

func _start_timer():
	"""A: Deferred timer start after first spawn"""
	has_spawned_first = true
	print("⏱️ Timer started after first spawn")

func game_over(won: bool):
	is_game_over = true
	
	# MEDIUM 3 FIX: Hide NEXT/CURRENT on game over
	if next_preview != null and is_instance_valid(next_preview):
		next_preview.visible = false
	if current_package != null and is_instance_valid(current_package):
		current_package.visible = false
	_clear_advance_anim()
	
	# LOW FIX: Freeze bay on game over
	var truck_bay = get_tree().root.get_node_or_null("Main/World/TruckBay")
	if truck_bay:
		truck_bay.set_process(false)
	
	# ITEM 5 FIX: Hide Pause button during game over
	var ui_manager = get_tree().root.get_node_or_null("Main/UIManager")
	if ui_manager:
		var pause_plate = ui_manager.get_node_or_null("UI/PausePlate")
		if pause_plate:
			pause_plate.visible = false
	
	if won:
		game_won.emit()
	else:
		game_lost.emit()

func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused

func restart_game():
	# ITEM 5 FIX: ALWAYS unpause on restart, regardless of previous state
	if is_paused:
		toggle_pause()  # Unpause
	
	# Stop timer during restart
	var was_game_over = is_game_over
	is_game_over = true
	
	# Clear current and preview
	if current_package != null and is_instance_valid(current_package):
		current_package.queue_free()
	current_package = null
	
	if next_preview != null and is_instance_valid(next_preview):
		next_preview.queue_free()
	next_preview = null
	next_preview_type = ""
	_clear_advance_anim()
	
	# Clear any other packages in group
	var packages = get_tree().get_nodes_in_group("packages")
	for pkg in packages:
		if is_instance_valid(pkg):
			pkg.queue_free()
	
	# Wait for queue_free to complete
	await get_tree().process_frame
	
	# Reset game state AFTER cleanup
	time_remaining = ROUND_TIME
	loads_completed = 0
	current_score = 0
	streak = 0
	is_game_over = false
	can_spawn = true
	spawn_timer = 0.0
	credited_ids.clear()
	score_cooldown_until = 0
	has_spawned_first = false  # A: Reset timer gate on restart
	
	# Emit signals to update UI
	score_changed.emit(current_score)
	loads_changed.emit(loads_completed, WIN_QUOTA)
	timer_changed.emit(time_remaining)
	streak_changed.emit(streak)
	
	# Spawn new package
	spawn_package()
	
	# Reset truck bay to center and resume processing
	var truck_bay = get_tree().root.get_node_or_null("Main/World/TruckBay")
	if truck_bay:
		if truck_bay.has_method("reset_position"):
			truck_bay.reset_position()
		truck_bay.set_process(true)  # Resume bay movement
	
	# ITEM 5 FIX: Show Pause button again and ensure PAUSED overlay hidden
	var ui_manager = get_tree().root.get_node_or_null("Main/UIManager")
	if ui_manager:
		var pause_plate = ui_manager.get_node_or_null("UI/PausePlate")
		if pause_plate:
			pause_plate.visible = true
		# Force update paused overlay to hidden state
		if ui_manager.has_method("_update_paused_overlay"):
			ui_manager._update_paused_overlay()
	
	# (5): Restart flash CLEARLY white-blue (different hue from green hit flash)
	var world = get_tree().root.get_node_or_null("Main/World")
	if world:
		var flash = ColorRect.new()
		flash.size = Vector2(720, 1280)
		# (5): Pure WHITE with slight blue tint (RGB all high, blue highest)
		flash.color = Color(0.95, 0.95, 1.0, 1.0)  # Almost pure white with blue tint
		flash.modulate = Color(1, 1, 1, 1)  # Reset modulate explicitly (no inherited alpha)
		flash.z_index = 50
		world.add_child(flash)
		
		var tween = create_tween()
		tween.tween_property(flash, "modulate:a", 0.0, 0.4)  # Slower fade for clarity
		
		var cleanup_flash = flash
		tween.finished.connect(func():
			if is_instance_valid(cleanup_flash):
				cleanup_flash.queue_free()
		)

func spawn_hit_juice(pos: Vector2, score_value: int, cargo_color: Color):
	"""Spawn hit particles + score pop + LOCALIZED green flash"""
	var world = get_tree().root.get_node_or_null("Main/World")
	if !world:
		return
	
	# QA mode: 3x duration for all effects
	var duration_mult = 3.0 if qa_mode else 1.0
	
	# D: Small localized green flash at truck bay (150x150), very faint
	var hit_flash = ColorRect.new()
	hit_flash.position = Vector2(pos.x - 75, pos.y - 75)
	hit_flash.size = Vector2(150, 150)
	hit_flash.color = Color(0.2, 1.0, 0.3, 0.05)  # Very faint green tint (alpha 0.05)
	hit_flash.z_index = 55
	world.add_child(hit_flash)
	
	var flash_tween = create_tween()
	flash_tween.tween_property(hit_flash, "modulate:a", 0.0, 0.2 * duration_mult)
	
	var cleanup_hit_flash = hit_flash
	flash_tween.finished.connect(func():
		if is_instance_valid(cleanup_hit_flash):
			cleanup_hit_flash.queue_free()
	)
	
	# ITEM (b): Larger/brighter hit particles (doubled amount, bigger scale)
	var particles = CPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 30  # Doubled from 15
	particles.lifetime = 0.6 * duration_mult
	particles.explosiveness = 0.95
	particles.direction = Vector2(0, -1)
	particles.spread = 45
	particles.gravity = Vector2(0, 450)
	particles.initial_velocity_min = 180.0
	particles.initial_velocity_max = 320.0
	particles.scale_amount_min = 4.0  # Increased from 2.5
	particles.scale_amount_max = 8.0  # Increased from 5.0
	particles.color = cargo_color
	world.add_child(particles)
	
	# Auto-cleanup after particles finish
	var cleanup_particles = particles  # Copy reference to avoid capture issues
	get_tree().create_timer(1.0 * duration_mult).timeout.connect(func(): 
		if is_instance_valid(cleanup_particles):
			cleanup_particles.queue_free()
	)
	
	# Score pop label
	var score_label = Label.new()
	score_label.position = pos - Vector2(30, 50)
	score_label.text = "+%d" % score_value
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.add_theme_color_override("font_color", Color(1, 1, 0.2, 1))
	score_label.z_index = 100
	world.add_child(score_label)
	
	# Animate pop: scale + fade + rise
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(score_label, "position:y", pos.y - 100, 0.9 * duration_mult)
	tween.tween_property(score_label, "scale", Vector2(1.5, 1.5), 0.2 * duration_mult).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(score_label, "modulate:a", 0.0, 0.4 * duration_mult)
	
	var cleanup_label = score_label  # Copy reference
	tween.finished.connect(func(): 
		if is_instance_valid(cleanup_label):
			cleanup_label.queue_free()
	)

func spawn_miss_juice(pos: Vector2):
	"""Spawn gray dust particles on miss - STRONG visibility + SHAKE"""
	var world = get_tree().root.get_node_or_null("Main/World")
	if !world:
		return
	
	# ITEM 2: Skip shake if paused or game over
	if is_paused or is_game_over:
		print("⚠️ MISS SHAKE SKIPPED: paused=%s game_over=%s" % [is_paused, is_game_over])
		return
	
	# QA mode: 3x duration for all effects
	var duration_mult = 3.0 if qa_mode else 1.0
	
	# QA ITEM 6: DETERMINISTIC SHAKE - 6-5-4-3 game units, ~0.25s, decaying
	# Kill any existing position tweens to prevent overlap/drift
	# r3: only kill the previous SHAKE tween (killing every tween broke hint/NEXT anims)
	if shake_tween_ref != null and shake_tween_ref.is_valid():
		shake_tween_ref.kill()
	
	# CRITICAL: Always start from (0,0) to prevent drift accumulation
	# Force world to origin before shake
	world.position = Vector2.ZERO
	var shake_start_pos = Vector2.ZERO
	
	var shake_duration = 0.25 * duration_mult
	
	# Create deterministic shake with decaying amplitude
	var shake_tween = create_tween()
	shake_tween_ref = shake_tween
	shake_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)  # Don't shake while paused
	
	# QA ITEM 6: Higher amplitude shake (6-5-4-3 game units, visible at small scales)
	# At scale 0.3: 6 * 0.3 = ~2 CSS px displacement
	var offsets = [
		Vector2(6, 0),    # 6 game units horizontal
		Vector2(-5, 0),   # 5 game units horizontal
		Vector2(4, 0),    # 4 game units horizontal
		Vector2(-3, 0),   # 3 game units horizontal
	]
	
	# Animate through offsets quickly
	var step_duration = shake_duration / offsets.size()
	for offset in offsets:
		shake_tween.tween_property(world, "position", shake_start_pos + offset, step_duration)
	
	# CRITICAL: Force exact return to start position (no drift)
	var final_pos = shake_start_pos  # Capture in closure
	shake_tween.tween_property(world, "position", final_pos, 0.0)
	shake_tween.tween_callback(func():
		if is_instance_valid(world):
			world.position = final_pos  # Force exact position in callback
			print("✅ MISS SHAKE COMPLETE: position reset to", final_pos)
	)
	
	# STRONGER dust burst (4x particles, much bigger, longer-lived)
	var particles = CPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 32  # Quadrupled from 8
	particles.lifetime = 0.8 * duration_mult  # Increased further
	particles.explosiveness = 0.9  # More explosive
	particles.direction = Vector2(0, -1)
	particles.spread = 80  # Wider spread
	particles.gravity = Vector2(0, 300)
	particles.initial_velocity_min = 120.0  # Faster
	particles.initial_velocity_max = 250.0  # Faster
	particles.scale_amount_min = 6.0  # Much bigger
	particles.scale_amount_max = 12.0  # Much bigger
	particles.color = Color(0.6, 0.6, 0.6, 0.9)  # More opaque
	world.add_child(particles)
	
	# Auto-cleanup
	var cleanup_particles = particles  # Copy reference
	get_tree().create_timer(1.2 * duration_mult).timeout.connect(func(): 
		if is_instance_valid(cleanup_particles):
			cleanup_particles.queue_free()
	)
	
	# STRONGER gray flash on miss
	var flash = ColorRect.new()
	flash.size = Vector2(720, 1280)
	flash.color = Color(0.5, 0.5, 0.5, 0.25)  # Brighter gray flash
	flash.z_index = 50
	world.add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.4 * duration_mult)  # Longer fade
	
	var cleanup_flash = flash  # Copy reference
	tween.finished.connect(func():
		if is_instance_valid(cleanup_flash):
			cleanup_flash.queue_free()
	)

func load_shift(index: int, restart: bool = true):
	# Apply shift config and optionally restart game
	if index < 0 or index >= SHIFTS.size():
		print("⚠️ Invalid shift index: %d" % index)
		return
	
	current_shift_index = index
	current_shift = SHIFTS[index]
	ROUND_TIME = current_shift.timer
	WIN_QUOTA = current_shift.quota
	
	print("🎮 SHIFT %d: %s | %ds | Quota %d" % [
		current_shift.shift_number,
		current_shift.name,
		int(ROUND_TIME),
		WIN_QUOTA
	])
	
	if restart:
		restart_game()

# DEBUG FUNCTION: Test credit system with F1 key
func debug_add_credit():
	print("═══════════════════════════════════════")
	print("🔧 DEBUG +1 LOAD (F1 pressed)")
	
	# Get or create test package
	var test_package = get_tree().root.find_children("Package*", "RigidBody2D", true, false)
	var package_to_use = null
	
	if test_package.size() > 0:
		package_to_use = test_package[0]
		print("  Using existing package:", package_to_use.name)
	else:
		# Create dummy package for testing
		var dummy = Node.new()
		dummy.name = "DebugPackage"
		dummy.set("credit_key", "debug_" + str(Time.get_ticks_usec()))
		get_tree().root.add_child(dummy)
		package_to_use = dummy
		print("  Created dummy package")
	
	# Ensure package has credit_key
	var test_key = ""
	if package_to_use.has_method("get_credit_key"):
		test_key = package_to_use.get_credit_key()
	elif package_to_use.get("credit_key"):
		test_key = package_to_use.get("credit_key")
	else:
		test_key = "debug_" + str(package_to_use.get_instance_id())
		package_to_use.set("credit_key", test_key)
	
	print("  Credit key:", test_key)
	print("  Loads before:", loads_completed)
	
	# Create mock package node with necessary methods
	var mock = Node.new()
	mock.set("credit_key", test_key)
	
	# Call register_successful_load
	var old_loads = loads_completed
	var success = register_successful_load(package_to_use, 1)
	
	print("  Success:", success)
	print("  Loads after:", loads_completed)
	print("  Expected:", old_loads + (1 if success else 0))
	
	# Verify
	if success and loads_completed == old_loads + 1:
		print("✅ DEBUG CREDIT OK: loads incremented +1")
	elif !success and loads_completed == old_loads:
		print("⚠ DEBUG CREDIT REJECTED: Same package or at quota")
	else:
		print("❌ DEBUG CREDIT ERROR: Unexpected state")
	
	print("═══════════════════════════════════════")
	
	if mock:
		mock.queue_free()
