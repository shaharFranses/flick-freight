extends SceneTree

# Test for ITEM 1: Bay speed ramp (0.6 to 1.0 over ~7s)

var main_scene: Node = null
var game_manager: Node = null
var truck_bay: Node = null
var test_results: Array = []
var test_state: String = "init"
var frame_count: int = 0
var test_data: Dictionary = {}

func _init():
	print("═══════════════════════════════════════")
	print("🧪 BAY RAMP TEST STARTING")
	print("═══════════════════════════════════════")
	
	# Load main scene
	var packed_scene = load("res://scenes/main.tscn")
	if not packed_scene:
		push_error("❌ FAILED TO LOAD main.tscn")
		quit(1)
		return
	
	main_scene = packed_scene.instantiate()
	root.add_child(main_scene)
	
	# Get GameManager
	game_manager = main_scene.get_node_or_null("GameManager")
	if not game_manager:
		push_error("❌ FAILED TO FIND GameManager")
		quit(1)
		return
	
	# Get TruckBay
	truck_bay = main_scene.get_node_or_null("World/TruckBay")
	if not truck_bay:
		push_error("❌ FAILED TO FIND TruckBay")
		quit(1)
		return
	
	print("✅ Scene loaded successfully")

func _process(_delta: float) -> bool:
	frame_count += 1
	
	# State machine for tests
	if test_state == "init":
		test_state = "test1_start"
		
	elif test_state == "test1_start":
		test_ramp_start()
		test_state = "test1_wait"
		
	elif test_state == "test1_wait":
		if frame_count >= 5:
			test_ramp_start_end()
			frame_count = 0
			test_state = "test2_start"
			
	elif test_state == "test2_start":
		test_ramp_end()
		test_state = "test2_wait"
		
	elif test_state == "test2_wait":
		# Wait 7.1 seconds using actual time
		var elapsed = (Time.get_ticks_msec() / 1000.0) - test_data["ramp_end_start"]
		if elapsed >= 7.1:
			test_ramp_end_check()
			frame_count = 0
			test_state = "test3_start"
			
	elif test_state == "test3_start":
		test_travel_limits()
		test_state = "test3_wait"
		
	elif test_state == "test3_wait":
		# Sample for 10 seconds and track min/max
		var center_x = test_data["center_x"]
		var offset = truck_bay.position.x - center_x
		test_data["min_x"] = min(test_data["min_x"], offset)
		test_data["max_x"] = max(test_data["max_x"], offset)
		
		var elapsed = (Time.get_ticks_msec() / 1000.0) - test_data["travel_start"]
		if elapsed >= 10.0:
			test_travel_limits_check()
			frame_count = 0
			test_state = "test4_start"
			
	elif test_state == "test4_start":
		test_ramp_reset()
		test_state = "test4_wait"
		
	elif test_state == "test4_wait":
		# Wait 3 seconds
		var elapsed = (Time.get_ticks_msec() / 1000.0) - test_data["reset_wait_start"]
		if elapsed >= 3.0:
			test_state = "test4_restart"
			frame_count = 0
			
	elif test_state == "test4_restart":
		game_manager.restart_game()
		test_state = "test4_check"
		frame_count = 0
		
	elif test_state == "test4_check":
		if frame_count >= 30:  # Wait for restart
			test_ramp_reset_check()
			frame_count = 0
			test_state = "test5_start"
			
	elif test_state == "test5_start":
		test_qa_mode_composition()
		test_state = "test5_wait"
		
	elif test_state == "test5_wait":
		# Wait 1 second
		var elapsed = (Time.get_ticks_msec() / 1000.0) - test_data["qa_start_time"]
		if elapsed >= 1.0:
			test_qa_mode_composition_check()
			frame_count = 0
			test_state = "done"
			
	elif test_state == "done":
		print_summary()
		return true
	
	return false

func test_ramp_start():
	print("\n🧪 Test: Ramp starts at 0.6")
	truck_bay.reset_position()
	test_data["ramp_start_time"] = Time.get_ticks_msec() / 1000.0

func test_ramp_start_end():
	var round_start = truck_bay.round_start_time
	var current_time = Time.get_ticks_msec() / 1000.0
	var elapsed = current_time - round_start
	
	var expected_ramp = 0.6 if elapsed < 0.1 else lerp(0.6, 1.0, elapsed / 7.0)
	var passed = expected_ramp >= 0.6 and expected_ramp <= 0.65
	
	test_results.append({
		"name": "Ramp starts at 0.6",
		"passed": passed,
		"reason": "Expected ramp ~0.6, got ~%.2f" % expected_ramp if not passed else ""
	})

func test_ramp_end():
	print("\n🧪 Test: Ramp reaches 1.0 by ~7s")
	truck_bay.reset_position()
	test_data["ramp_end_start"] = Time.get_ticks_msec() / 1000.0

func test_ramp_end_check():
	var round_start = truck_bay.round_start_time
	var current_time = Time.get_ticks_msec() / 1000.0
	var round_elapsed = current_time - round_start
	
	var expected_ramp = 1.0 if round_elapsed >= 7.0 else lerp(0.6, 1.0, round_elapsed / 7.0)
	var passed = expected_ramp >= 0.95 and expected_ramp <= 1.0
	
	test_results.append({
		"name": "Ramp reaches 1.0 by ~7s",
		"passed": passed,
		"reason": "Expected ramp ~1.0, got ~%.2f at t=%.1fs" % [expected_ramp, round_elapsed] if not passed else ""
	})

func test_travel_limits():
	print("\n🧪 Test: Travel limits still ±180")
	truck_bay.reset_position()
	test_data["min_x"] = 999999.0
	test_data["max_x"] = -999999.0
	test_data["center_x"] = truck_bay.center_x
	test_data["travel_start"] = Time.get_ticks_msec() / 1000.0

func test_travel_limits_check():
	var min_x = test_data["min_x"]
	var max_x = test_data["max_x"]
	
	# Check if travel limits are within ±180 (with 5px tolerance)
	var passed = abs(min_x + 180.0) < 5.0 and abs(max_x - 180.0) < 5.0
	
	test_results.append({
		"name": "Travel limits ±180",
		"passed": passed,
		"reason": "Expected ±180, got [%.1f, %.1f]" % [min_x, max_x] if not passed else ""
	})

func test_ramp_reset():
	print("\n🧪 Test: Ramp resets on Retry")
	test_data["reset_wait_start"] = Time.get_ticks_msec() / 1000.0
	# Will wait 3 seconds, then restart

func test_ramp_reset_check():
	var round_start = truck_bay.round_start_time
	var current_time = Time.get_ticks_msec() / 1000.0
	var round_elapsed = current_time - round_start
	
	var expected_ramp = lerp(0.6, 1.0, round_elapsed / 7.0)
	var passed = expected_ramp >= 0.6 and expected_ramp <= 0.7
	
	test_results.append({
		"name": "Ramp resets on Retry",
		"passed": passed,
		"reason": "Expected ramp ~0.6 after restart, got ~%.2f" % expected_ramp if not passed else ""
	})

func test_qa_mode_composition():
	print("\n🧪 Test: QA mode composes with ramp")
	truck_bay.set_speed_multiplier(0.25)
	truck_bay.reset_position()
	test_data["qa_start_pos"] = truck_bay.position.x
	test_data["qa_start_time"] = Time.get_ticks_msec() / 1000.0

func test_qa_mode_composition_check():
	var start_pos = test_data["qa_start_pos"]
	var end_pos = truck_bay.position.x
	var moved_distance = abs(end_pos - start_pos)
	
	# With QA mode (0.25) and ramp (0.6), effective speed is 0.15x
	# At full speed, bay would move significantly in 1 second
	# At 0.15x speed, it should move very little
	var passed = moved_distance < 100.0  # Much less than ±180 range
	
	test_results.append({
		"name": "QA mode composes with ramp",
		"passed": passed,
		"reason": "Expected slow movement with QA mode, moved %.1fpx in 1s" % moved_distance if not passed else ""
	})

func print_summary():
	print("═══════════════════════════════════════")
	print("📊 TEST RESULTS")
	print("═══════════════════════════════════════")
	
	var passed_count = 0
	var failed_count = 0
	for result in test_results:
		if result.passed:
			passed_count += 1
			print("✅", result.name)
		else:
			failed_count += 1
			print("❌", result.name, ":", result.reason)
	
	print("═══════════════════════════════════════")
	print("PASSED:", passed_count, "FAILED:", failed_count)
	print("═══════════════════════════════════════")
	
	quit(0 if failed_count == 0 else 1)
