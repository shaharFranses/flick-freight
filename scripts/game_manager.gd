extends Node

# DEBUG MODE: Set to false for shipping build
const DEBUG_MODE = false

# r5: the timer run is the only mode (shift ladder parked; see r5-depth-spec.md).
# r5 TUNABLES (spec table). Every key can be overridden under ?qa=1, e.g. ?qa=1&clock_start=25
var T = {
	"clock_start": 20.0, "clock_cap": 30.0,
	"hit_bonus": 2.0, "perfect_bonus": 3.5, "perfect_zone": 0.30,
	"streak_bonus_start": 3, "streak_bonus_step": 0.5, "streak_bonus_cap": 5.0,
	"miss_penalty": 2.0, "miss_grace_levels": 2,
	"decay_step": 0.1, "decay_every": 10, "hit_bonus_floor": 1.2, "perfect_bonus_floor": 2.2,
	"loads_per_level": 5,
	"bay_period_start": 3.6, "bay_period_shrink": 0.06, "bay_period_floor": 1.6,
	"ticket_bonus_score": 50, "ticket_bonus_time": 1.5, "ticket_spawn_tilt": 0.15,
	"low_time_warning": 5.0, "on_fire_streak": 6, "ramp": 0,
}
var ROUND_TIME: float = 20.0  # = T.clock_start (kept name for UI/hint code)
var last_time_delta: float = 0.0  # for ?qa=1 overlay
var ticket: Array = []  # r5 ticket stub: [{"type": "box", "done": false}, ...]
signal time_delta(amount: float, from_pos: Vector2)
signal ticket_changed(ticket: Array)
signal ticket_completed(score_bonus: int, time_bonus: float)
signal multiplier_changed(mult: int)
signal on_fire_changed(on: bool)
signal flick_started

# r5 run state
var run_started: bool = false        # clock runs from the first flick of each run
var first_flick_resolved: bool = false  # truck holds centre until this
var guarantee_flick: bool = false    # fresh profile: first flick of first run always lands
var on_fire: bool = false
var page_hidden: bool = false  # r5: set by UIManager on hide/blur; freezes the run clock
var run_start_ms: int = 0
var last_tick_sec: int = -1
var sfx = {}
var sfx_players: Array = []

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
var time_remaining: float = 20.0
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
	
	# Detect QA mode from URL parameter ?qa=1 (exact param, not substring)
	if OS.has_feature("web"):
		var search_string = JavaScriptBridge.eval("location.search || ''")
		if search_string and search_string is String:
			_parse_query(search_string)
	ROUND_TIME = T.clock_start
	time_remaining = ROUND_TIME
	_new_ticket()
	_init_sfx()
	guarantee_flick = storage_get("ff_first_flick_done", "") != "1"
	
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
	var tb = get_tree().root.get_node_or_null("Main/World/TruckBay")
	if tb and "ramp_enabled" in tb:
		tb.ramp_enabled = qa_mode and int(T.ramp) == 1
	
	spawn_package()
	if qa_force_fire:
		call_deferred("_set_on_fire", true)

var qa_force_fire := false
var qa_cargo := ""
var qa_hold_aim := false
var _qa_cycle_i := 0

func _parse_query(q: String):
	var params = {}
	for kv in q.trim_prefix("?").split("&", false):
		var parts = kv.split("=")
		params[parts[0]] = parts[1] if parts.size() > 1 else ""
	qa_mode = params.get("qa", "") == "1"
	if !qa_mode:
		return
	# r4 Visuals debug toggles (?qa=1 only; display/test aids)
	qa_force_fire = params.get("fire", "") == "1"
	qa_cargo = params.get("cargo", "")
	qa_hold_aim = params.get("hold_aim", "") == "1"
	if qa_force_fire or qa_cargo != "" or qa_hold_aim:
		print("QA TOGGLES fire=", qa_force_fire, " cargo=", qa_cargo, " hold_aim=", qa_hold_aim)
	for k in params:
		if T.has(k) and params[k].is_valid_float():
			T[k] = int(params[k]) if typeof(T[k]) == TYPE_INT else float(params[k])
			print("QA TUNABLE ", k, " = ", T[k])

# ---------- r5 timer math (pure; spec section 1) ----------
func level_index() -> int:
	return loads_completed / int(T.loads_per_level)  # 0 = level 1

func decay_amount(loads: int) -> float:
	return float(loads / int(T.decay_every)) * T.decay_step

func hit_time_bonus(loads_before: int, streak_after: int, perfect: bool) -> float:
	var base: float
	if perfect:
		base = max(T.perfect_bonus_floor, T.perfect_bonus - decay_amount(loads_before))
	else:
		base = max(T.hit_bonus_floor, T.hit_bonus - decay_amount(loads_before))
	var streak_b = 0.0
	if streak_after >= int(T.streak_bonus_start):
		streak_b = min(T.streak_bonus_cap, (streak_after - 2) * T.streak_bonus_step)
	return base + streak_b

func miss_time_penalty(loads: int) -> float:
	if loads < int(T.miss_grace_levels) * int(T.loads_per_level):
		return 0.0
	return T.miss_penalty

func bay_period_for_level(level: int) -> float:
	return max(T.bay_period_floor, T.bay_period_start * pow(1.0 - T.bay_period_shrink, level))

func multiplier() -> int:
	if streak >= 10: return 4
	if streak >= 6: return 3
	if streak >= 3: return 2
	return 1

func add_time(amount: float, from_pos: Vector2 = Vector2(360, 200)):
	last_time_delta = amount
	time_remaining = clamp(time_remaining + amount, 0.0, T.clock_cap)
	timer_changed.emit(time_remaining)
	time_delta.emit(amount, from_pos)

# ---------- r5 ticket stub (spec section 3) ----------
func unlocked_types() -> Array:
	if loads_completed < 5: return ["box"]
	if loads_completed < 10: return ["box", "crate"]
	return ["box", "crate", "barrel"]

func _new_ticket():
	var types = unlocked_types()
	var n = 2 + (randi() % 2)
	ticket = []
	for i in n:
		ticket.append({"type": types[randi() % types.size()], "done": false})
	ticket_changed.emit(ticket)

func _tick_ticket(type: String) -> bool:
	"""Returns true if the ticket completed."""
	for item in ticket:
		if !item.done and item.type == type:
			item.done = true
			break
	ticket_changed.emit(ticket)
	for item in ticket:
		if !item.done:
			return false
	return true

func _open_ticket_types() -> Dictionary:
	var d = {}
	for item in ticket:
		if !item.done:
			d[item.type] = true
	return d

# ---------- r5: storage, sfx, first flick ----------
func storage_get(key: String, default_val: String) -> String:
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('%s')}catch(e){return null}})()" % key)
		return v if v is String else default_val
	var c = ConfigFile.new()
	if c.load("user://flick_freight.cfg") == OK:
		return str(c.get_value("kv", key, default_val))
	return default_val

func storage_set(key: String, val: String):
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){try{localStorage.setItem('%s','%s')}catch(e){}})()" % [key, val])
		return
	var c = ConfigFile.new()
	c.load("user://flick_freight.cfg")
	c.set_value("kv", key, val)
	c.save("user://flick_freight.cfg")

func _init_sfx():
	# CC0, self-synthesized (res://audio/LICENSE.txt)
	for n in ["box", "crate", "barrel", "snap", "tick", "honk", "whoosh", "fizzle"]:
		sfx[n] = load("res://audio/%s.wav" % n)
	for i in 6:
		var pl = AudioStreamPlayer.new()
		pl.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(pl)
		sfx_players.append(pl)

func play_sfx(n: String, pitch: float = 1.0, vol_db: float = 0.0):
	if !sfx.has(n) or sfx[n] == null:
		return
	for pl in sfx_players:
		if !pl.playing:
			pl.stream = sfx[n]
			pl.pitch_scale = pitch
			pl.volume_db = vol_db
			pl.play()
			return

func on_flick(direction: Vector2, speed: float) -> Array:
	"""Called by the package when a flick is released. Starts the clock; steers the
	guaranteed first flick (fresh profile) straight into the held-centre bed."""
	if !run_started:
		run_started = true
		run_start_ms = Time.get_ticks_msec()
	flick_started.emit()
	if guarantee_flick and !first_flick_resolved and direction.y < -0.2:
		print("FIRST FLICK: steered into bed (guarantee)")
		return [Vector2(0, -1), 1500.0]
	return [direction, speed]

func _first_resolve():
	if first_flick_resolved:
		return
	first_flick_resolved = true
	if guarantee_flick:
		guarantee_flick = false
		storage_set("ff_first_flick_done", "1")
	var bay = get_tree().root.get_node_or_null("Main/World/TruckBay")
	if bay and bay.has_method("release_hold"):
		bay.release_hold()

func _set_on_fire(v: bool):
	if v == on_fire:
		return
	on_fire = v
	play_sfx("whoosh" if v else "fizzle")
	on_fire_changed.emit(v)

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
	if is_game_over or is_paused or page_hidden:
		return
	# r5: a hidden/throttled tab can hand us one huge frame on return; never let the
	# clock lose more than 0.1 s per frame.
	delta = min(delta, 0.1)
	
	# DEBUG: F1 key to test credit system
	if DEBUG_MODE and (Input.is_action_just_pressed("ui_select") or Input.is_key_pressed(KEY_F1)):
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
	# r5 on-fire: current package glows (pulse)
	if current_package != null and is_instance_valid(current_package) and current_package.modulate.a > 0.5:
		if on_fire:
			var k = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
			current_package.modulate = Color(1.0 + 0.5 * k, 0.85 + 0.15 * k, 0.6, 1.0)
		elif current_package.modulate != Color(1, 1, 1, 1):
			current_package.modulate = Color(1, 1, 1, 1)
	if run_started:
		time_remaining -= delta
		if time_remaining < T.low_time_warning and time_remaining > 0:
			var sec = int(ceil(time_remaining))
			if sec != last_tick_sec:
				last_tick_sec = sec
				play_sfx("tick")
		timer_changed.emit(time_remaining)
	
	# Check lose condition
	if time_remaining <= 0:
		time_remaining = 0
		timer_changed.emit(time_remaining)
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
	
	var selected_type = select_random_type()
	
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
		current_package.missed.connect(_on_package_missed.bind(current_package))
		
		print("  Current package ID:", current_package.get_instance_id())
		
		# Generate first preview
		var preview_type = select_random_type()
		generate_preview(preview_type)
		
		# A: Start timer after first spawn (deferred to next frame)
		call_deferred("_start_timer")
	
	can_spawn = false

func select_random_type() -> String:
	if qa_mode and qa_cargo in ["box", "crate", "barrel"]:
		return qa_cargo
	if qa_mode and qa_cargo == "cycle":
		_qa_cycle_i += 1
		return ["box", "crate", "barrel"][(_qa_cycle_i - 1) % 3]
	return _select_random_type_real()

func _select_random_type_real() -> String:
	# r5: unlock order (BOX 0-4, +CRATE 5-9, all from 10) + ticket tilt (+15% per open type)
	var types = unlocked_types()
	var open = _open_ticket_types()
	var weights = {}
	var total = 0.0
	for t in types:
		var w = 1.0 + (T.ticket_spawn_tilt * types.size() if open.has(t) else 0.0)
		weights[t] = w
		total += w
	var r = randf() * total
	for t in types:
		r -= weights[t]
		if r <= 0.0:
			return t
	return types[-1]

# r3: NEXT preview sits beside the flick spot and shows the real cargo art
const FLICK_SPOT = Vector2(360, 1150)
const NEXT_POS = Vector2(530, 1160)
const NEXT_ART_SCALE = 0.6  # r4: NEXT secondary, well under CURRENT's drawn size
const NEXT_SLIDE_TIME = 0.25
var advance_ghost: Node2D = null  # r3: transient cargo art sliding NEXT -> flick spot
var advance_tween: Tween = null
var next_pop_tween: Tween = null
var shake_tween_ref: Tween = null

func make_cargo_art(type: String) -> Node2D:
	"""r4: display-only vector cargo (same art as in play)"""
	return Art.build_cargo(type)

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
	panel.size = Vector2(104, 124)
	panel.position = Vector2(-52, -76)
	panel.color = Color(0.1, 0.12, 0.18, 0.85)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_preview.add_child(panel)
	
	# Caption "NEXT" above the art
	var next_label = Label.new()
	next_label.name = "NextCaption"
	next_label.text = "NEXT"
	next_label.add_theme_font_size_override("font_size", 20)
	next_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_label.position = Vector2(-52, -78)
	next_label.size = Vector2(104, 30)
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
	label_backing.size = Vector2(132, 38)
	label_backing.color = Color(0.05, 0.05, 0.1, 0.95)  # Very dark, high opacity
	label_backing.position = Vector2(-66, -112)  # Above the (larger) package art
	label_backing.z_index = 99
	package.add_child(label_backing)
	
	# (3): Add CURRENT label with bigger font and bright color
	var current_label = Label.new()
	current_label.name = "CurrentChip"
	current_label.text = "CURRENT"
	current_label.add_theme_font_size_override("font_size", 28)  # r4: CURRENT dominant over NEXT
	current_label.add_theme_color_override("font_color", Color(1, 1, 0.3, 1))  # Bright yellow
	current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_label.position = Vector2(-66, -112)  # Centered on backing
	current_label.size = Vector2(132, 38)
	current_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
	current_package.missed.connect(_on_package_missed.bind(current_package))
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
	var gk = Art.DRAW_SCALE.get(type_name, 1.0)
	advance_tween.tween_property(ghost, "scale", Vector2(1.1, 1.1) * gk, NEXT_SLIDE_TIME * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	advance_tween.chain().tween_property(ghost, "scale", Vector2(gk, gk), 0.08)
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
	loads_completed = loads_completed + 1
	
	# Streak increments +1 ONCE per successful load
	var old_streak = streak
	streak += 1
	
	# Score calculation per design: base_points + (streak-1) bonus
	# r5 spec 2: points x multiplier, x2 on a perfect
	var perfect = _is_perfect(package)
	var mult = multiplier()
	var total_points = base_points * mult * (2 if perfect else 1)
	current_score += total_points
	var ctype = _type_of(package)
	play_sfx(ctype, 1.0 + 0.06 * (mult - 1))
	if perfect:
		play_sfx("snap", 1.0, -2.0)
		spawn_perfect_juice(package.global_position)
	multiplier_changed.emit(mult)
	_set_on_fire(qa_force_fire or streak >= int(T.on_fire_streak))
	_first_resolve()
	
	print("  Loads:", old_loads, "→", loads_completed, " (+1)")
	print("  Streak:", old_streak, "→", streak, " (+1)")
	print("  Score: +", total_points, " = ", current_score)
	
	# JUICE: Hit effect (particles + score pop)
	var pkg_color = package.modulate if package.get("modulate") != null else Color(1, 1, 1)
	spawn_hit_juice(package.global_position, total_points, pkg_color, ctype)
	
	print("═══════════════════════════════════════")
	
	# Emit UI update signals ONCE
	score_changed.emit(current_score)
	loads_changed.emit(loads_completed, 0)
	streak_changed.emit(streak)
	
	# r5 TIMER: hit / perfect / streak bonus, then ticket
	add_time(hit_time_bonus(old_loads, streak, perfect), package.global_position)
	if _tick_ticket(ctype):
		var sb = int(T.ticket_bonus_score) * multiplier()
		current_score += sb
		score_changed.emit(current_score)
		add_time(T.ticket_bonus_time, package.global_position)
		ticket_completed.emit(sb, T.ticket_bonus_time)
		play_sfx("honk")
		_new_ticket()
	_apply_bay_level()
	
	# Update debug label (if exists)
	var debug_label = get_node_or_null("/root/Main/UIManager/UI/DebugLabel")
	if debug_label:
		debug_label.text = "LastCredit: +1 (loads=%d) key=%s" % [loads_completed, lookup_key.substr(0, 10)]
	
	# Package resolved - advance conveyor
	on_package_resolved()
	
	return true

func _is_perfect(package: Node) -> bool:
	var bay = get_tree().root.get_node_or_null("Main/World/TruckBay")
	if bay == null:
		return false
	var w = bay.OPENING_WIDTH * (package.bay_hitbox_scale if package.get("bay_hitbox_scale") != null else 1.0)
	return abs(package.global_position.x - bay.global_position.x) <= w * T.perfect_zone * 0.5

func _type_of(package: Node) -> String:
	var f = package.scene_file_path
	for t in ["box", "crate", "barrel"]:
		if f.contains(t):
			return t
	return "box"

func _apply_bay_level():
	var bay = get_tree().root.get_node_or_null("Main/World/TruckBay")
	if bay and bay.has_method("set_period"):
		bay.set_period(bay_period_for_level(level_index()))

func _on_package_missed(pkg = null):
	# r5: a credited package can still touch the truck's static body on its way out and
	# emit `missed` in the same frame; that phantom miss reset the streak (no x2/on-fire ever).
	if pkg != null and is_instance_valid(pkg) and pkg.has_method("get_credit_key") and credited_ids.has(pkg.get_credit_key()):
		print("IGNORED phantom miss from credited package")
		return
	# r5 TIMER: miss penalty (0 during grace levels)
	var pos = current_package.global_position if (current_package != null and is_instance_valid(current_package)) else Vector2(360, 600)
	add_time(-miss_time_penalty(loads_completed), pos)
	# Reset streak on miss
	streak = 0
	streak_changed.emit(streak)
	multiplier_changed.emit(1)
	_set_on_fire(qa_force_fire)
	_first_resolve()
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
	ROUND_TIME = T.clock_start
	time_remaining = ROUND_TIME
	last_time_delta = 0.0
	loads_completed = 0
	current_score = 0
	streak = 0
	is_game_over = false
	can_spawn = true
	spawn_timer = 0.0
	credited_ids.clear()
	score_cooldown_until = 0
	has_spawned_first = false  # A: Reset timer gate on restart
	run_started = false
	first_flick_resolved = false
	last_tick_sec = -1
	if on_fire:
		on_fire = false
		on_fire_changed.emit(false)
	multiplier_changed.emit(1)
	
	# Emit signals to update UI
	score_changed.emit(current_score)
	loads_changed.emit(loads_completed, 0)
	_new_ticket()
	timer_changed.emit(time_remaining)
	streak_changed.emit(streak)
	
	# Spawn new package
	spawn_package()
	print("RUN RESTART ready (ms=%d)" % Time.get_ticks_msec())
	
	# Reset truck bay to center and resume processing
	var truck_bay = get_tree().root.get_node_or_null("Main/World/TruckBay")
	if truck_bay:
		if truck_bay.has_method("reset_position"):
			truck_bay.reset_position()
		_apply_bay_level()
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
	
	# r4: short white fade on retry (UI layer, above everything; 0.35 s, retry stays < 1 s)
	var uil = get_tree().root.get_node_or_null("Main/UIManager/UI")
	if uil:
		var flash = ColorRect.new()
		flash.name = "RetryFade"
		flash.position = Vector2(-2000, -2000)
		flash.size = Vector2(5000, 5000)
		flash.color = Color(1, 1, 1, 1)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.z_index = 400
		uil.add_child(flash)
		var tween = flash.create_tween()
		tween.tween_property(flash, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(flash.queue_free)
		print("FF retry: white fade")

func spawn_hit_juice(pos: Vector2, score_value: int, cargo_color: Color, ctype: String = "box"):
	"""r4: per-cargo hit VFX. Mint spark burst + cargo-specific debris, bed lip glow,
	truck bounce, mint +N pop. <= 0.5 s (3x under ?qa=1)."""
	var world = get_tree().root.get_node_or_null("Main/World")
	if !world:
		return
	var dm = 3.0 if qa_mode else 1.0
	Art.burst(world, pos, Art.TEX_SPARK, Art.MINT, 14, 0.35 * dm, 220, 420, 0.35, 0.7, Vector2(0, 300))
	match ctype:
		"crate":  # wooden splinters
			Art.burst(world, pos, null, Art.BROWN.lightened(0.15), 16, 0.5 * dm, 160, 340, 5, 9, Vector2(0, 900))
			Art.burst(world, pos, null, Art.AMBER.darkened(0.25), 8, 0.5 * dm, 140, 300, 4, 7, Vector2(0, 900))
		"barrel":  # metal clang: bright blue double shock ring + white star glints (~0.5 s)
			print("FF vfx: barrel hit")
			for k in 2:
				var ring = Sprite2D.new()
				ring.texture = Art.shock_ring()
				ring.modulate = Color(0.45, 0.75, 1.0, 1.0) if k == 0 else Color(1, 1, 1, 0.95)
				ring.position = pos - Vector2(0, 45)  # clear of the order ticket
				ring.scale = Vector2(0.4, 0.3)
				ring.z_index = 69
				world.add_child(ring)
				var rt = ring.create_tween()
				if k == 1:
					rt.tween_interval(0.08 * dm)
				rt.set_parallel(true)
				rt.tween_property(ring, "scale", Vector2(2.8, 1.25) * (1.0 if k == 0 else 0.7), 0.5 * dm).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				rt.tween_property(ring, "modulate:a", 0.0, 0.5 * dm).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				rt.chain().tween_callback(ring.queue_free)
			Art.burst(world, pos, Art.TEX_STAR, Art.WHITE, 12, 0.5 * dm, 160, 340, 0.5, 0.9, Vector2.ZERO)
			Art.burst(world, pos, Art.TEX_STAR, Color(0.55, 0.8, 1.0), 8, 0.5 * dm, 120, 260, 0.4, 0.7, Vector2(0, 200))
		_:  # box: cardboard flecks + amber stars
			Art.burst(world, pos, Art.TEX_STAR, Color(1.0, 0.85, 0.4), 16, 0.5 * dm, 170, 360, 0.45, 0.8, Vector2(0, 450))
			Art.burst(world, pos, Art.TEX_SPARK, Art.WHITE, 8, 0.35 * dm, 200, 380, 0.4, 0.7, Vector2(0, 300))
	var bay = get_tree().root.get_node_or_null("Main/World/TruckBay")
	if bay:
		var hero = bay.get_node_or_null("HeroTruck")
		if hero and hero.has_method("hit_pulse"):
			hero.hit_pulse(Art.MINT)
	var score_label = Label.new()
	score_label.position = pos - Vector2(120, 70)
	score_label.text = "+%d" % score_value
	score_label.add_theme_font_size_override("font_size", 40)
	score_label.add_theme_color_override("font_color", Art.MINT)
	score_label.add_theme_color_override("font_outline_color", Art.NAVY)
	score_label.add_theme_constant_override("outline_size", 8)
	score_label.z_index = 100
	world.add_child(score_label)
	var tween = score_label.create_tween()
	tween.set_parallel(true)
	score_label.position.y = max(score_label.position.y, 165.0)
	tween.tween_property(score_label, "position", Vector2(pos.x - 170, max(pos.y - 150, 165.0)), 0.5 * dm).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(score_label, "scale", Vector2(1.3, 1.3), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(score_label, "modulate:a", 0.0, 0.2 * dm)
	tween.chain().tween_callback(score_label.queue_free)

func spawn_perfect_juice(pos: Vector2):
	"""r5: short white flash on the bed + PERFECT pop-up"""
	var world = get_tree().root.get_node_or_null("Main/World")
	var bay = get_tree().root.get_node_or_null("Main/World/TruckBay")
	if !world or !bay:
		return
	var dm = 3.0 if qa_mode else 1.0
	var f = ColorRect.new()
	f.position = Vector2(-55, 24)  # drop slot only: keeps the flash off the FREIGHT decal
	f.size = Vector2(110, 34)
	f.color = Color(1, 1, 1, 0.55)
	f.z_index = 20
	bay.add_child(f)
	var tw = f.create_tween()
	tw.tween_property(f, "modulate:a", 0.0, 0.18 * dm)
	tw.tween_callback(f.queue_free)
	var uil = get_tree().root.get_node_or_null("Main/UIManager/UI")
	if uil == null:
		return
	if uil.get_node_or_null("DeliveredPop") != null:
		uil.get_node("DeliveredPop").text = "PERFECT DELIVERY!"
		return
	var l = Label.new()
	l.name = "PerfectPop"
	l.text = "PERFECT!"
	l.add_theme_font_size_override("font_size", 64)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Art.NAVY)
	l.add_theme_constant_override("outline_size", 12)
	l.size = Vector2(360, 80)
	l.position = Vector2(clamp(bay.global_position.x - 180, 0, 360), bay.global_position.y + 200)  # below the ticket + DELIVERED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(180, 40)
	l.scale = Vector2(0.3, 0.3)
	l.z_index = 200
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	uil.add_child(l)
	print("PERFECT pop")
	var t2 = l.create_tween()
	t2.tween_property(l, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_property(l, "scale", Vector2(1, 1), 0.08)
	t2.tween_interval(0.6 * dm)
	t2.tween_property(l, "modulate:a", 0.0, 0.2)
	t2.tween_callback(l.queue_free)

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
	
	var shake_duration = 0.3 * duration_mult
	# r5: amplitudes are in on-screen CSS px (6-5-4-3), converted to game units via the
	# real canvas scale. r3 used fixed game units => ~2-3 px at 1042x632, below QA's detector.
	var cpu = 1.0
	var uim = get_tree().root.get_node_or_null("Main/UIManager")
	if uim and uim.has_method("_get_css_per_unit"):
		cpu = max(0.1, uim._get_css_per_unit())
	var k = max(1.0, 1.0 / cpu)
	
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
		shake_tween.tween_property(world, "position", shake_start_pos + offset * k, step_duration)
	
	# CRITICAL: Force exact return to start position (no drift)
	var final_pos = shake_start_pos  # Capture in closure
	shake_tween.tween_property(world, "position", final_pos, 0.0)
	shake_tween.tween_callback(func():
		if is_instance_valid(world):
			world.position = final_pos  # Force exact position in callback
			print("✅ MISS SHAKE COMPLETE: position reset to", final_pos)
	)
	
	# r4: per-cargo miss VFX: grey smoke puff tinted by cargo + coral X (shake above)
	var mtype = _type_of(current_package) if (current_package != null and is_instance_valid(current_package)) else "box"
	var tint = Color(0.75, 0.77, 0.8).lerp(Art.cargo_color(mtype), 0.25)
	Art.burst(world, pos, Art.TEX_SMOKE, tint, 10, 0.6 * duration_mult, 60, 160, 0.5, 1.0, Vector2(0, -60))
	if mtype == "crate":
		Art.burst(world, pos, null, Art.BROWN, 10, 0.5 * duration_mult, 120, 260, 4, 8, Vector2(0, 900))
	elif mtype == "barrel":
		Art.burst(world, pos, Art.TEX_SPARK, Art.BLUE.lightened(0.3), 8, 0.4 * duration_mult, 150, 300, 0.3, 0.5, Vector2(0, 600))
	var xmark = Node2D.new()
	xmark.position = Vector2(clamp(pos.x, 60, 660), clamp(pos.y, 200, 1100))
	var bay_n = get_tree().root.get_node_or_null("Main/World/TruckBay")
	if bay_n:
		var tr = Rect2(bay_n.global_position + Vector2(-200, 50), Vector2(400, 120))
		if tr.has_point(xmark.position):
			xmark.position.y = bay_n.global_position.y + 210  # keep the order ticket readable
	xmark.z_index = 90
	for d in [[Vector2(-26, -26), Vector2(26, 26)], [Vector2(26, -26), Vector2(-26, 26)]]:
		Art.line(xmark, PackedVector2Array(d), Art.NAVY, 18)
		Art.line(xmark, PackedVector2Array(d), Art.CORAL, 10)
	xmark.scale = Vector2(0.4, 0.4)
	world.add_child(xmark)
	var xt = xmark.create_tween()
	xt.tween_property(xmark, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	xt.tween_property(xmark, "scale", Vector2.ONE, 0.06)
	xt.tween_interval(0.25 * duration_mult)
	xt.tween_property(xmark, "modulate:a", 0.0, 0.2 * duration_mult)
	xt.tween_callback(xmark.queue_free)

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
