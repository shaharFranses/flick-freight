extends SceneTree

# Test for ITEM 2: Deterministic miss shake

var main_scene: Node = null
var game_manager: Node = null
var world: Node2D = null
var test_results: Array = []
var test_state: String = "init"
var frame_count: int = 0
var test_data: Dictionary = {}

func _init():
	print("═══════════════════════════════════════")
	print("🧪 MISS SHAKE TEST STARTING")
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
	
	# Get World node
	world = main_scene.get_node_or_null("World")
	if not world:
		push_error("❌ FAILED TO FIND World")
		quit(1)
		return
	
	print("✅ Scene loaded successfully")

func _process(_delta: float) -> bool:
	frame_count += 1
	
	# State machine for tests
	if test_state == "init":
		test_state = "test1_start"
		
	elif test_state == "test1_start":
		test_miss_shake_fires()
		test_state = "test1_trigger"
		
	elif test_state == "test1_trigger":
		# Trigger miss and wait a few frames
		if frame_count == 1:
			test_data["pos_before"] = world.position
			game_manager.spawn_miss_juice(Vector2(360, 600))
		elif frame_count >= 5:
			# Check if shake occurred
			var pos_during = world.position
			if pos_during != test_data["pos_before"]:
				test_data["shake_detected"] += 1
				print("  ✓ Shake %d: position changed from %s to %s" % [test_data["iteration"]+1, test_data["pos_before"], pos_during])
			else:
				print("  ✗ Shake %d: NO POSITION CHANGE" % [test_data["iteration"]+1])
			
			test_data["iteration"] += 1
			frame_count = 0
			
			if test_data["iteration"] < 10:
				test_state = "test1_wait"
			else:
				test_state = "test1_check"
		
	elif test_state == "test1_wait":
		# Wait for shake to complete (~30 frames = 0.5s)
		if frame_count >= 30:
			frame_count = 0
			test_state = "test1_trigger"
			
	elif test_state == "test1_check":
		test_miss_shake_fires_check()
		frame_count = 0
		test_state = "test2_start"
		
	elif test_state == "test2_start":
		test_no_offset_drift()
		test_state = "test2_trigger"
		
	elif test_state == "test2_trigger":
		# Trigger 5 misses
		if frame_count == 1:
			game_manager.spawn_miss_juice(Vector2(360, 600))
			test_data["miss_count"] += 1
		elif frame_count >= 36:  # 0.6s per miss
			frame_count = 0
			if test_data["miss_count"] < 5:
				test_state = "test2_trigger"
			else:
				test_state = "test2_wait"
		
	elif test_state == "test2_wait":
		# Wait for all tweens to finish
		if frame_count >= 60:
			test_no_offset_drift_check()
			frame_count = 0
			test_state = "test3_start"
			
	elif test_state == "test3_start":
		test_no_shake_when_paused()
		test_state = "test3_wait"
		
	elif test_state == "test3_wait":
		if frame_count >= 20:
			test_no_shake_when_paused_check()
			frame_count = 0
			test_state = "test4_start"
			
	elif test_state == "test4_start":
		test_no_shake_when_game_over()
		test_state = "test4_wait"
		
	elif test_state == "test4_wait":
		if frame_count >= 20:
			test_no_shake_when_game_over_check()
			frame_count = 0
			test_state = "done"
			
	elif test_state == "done":
		print_summary()
		return true
	
	return false

func test_miss_shake_fires():
	print("\n🧪 Test: Miss shake fires consistently (10 iterations)")
	test_data["shake_detected"] = 0
	test_data["iteration"] = 0
	frame_count = 0

func test_miss_shake_fires_check():
	var shake_detected = test_data["shake_detected"]
	var iterations = test_data["iteration"]
	var passed = shake_detected == iterations
	
	test_results.append({
		"name": "Miss shake fires consistently",
		"passed": passed,
		"reason": "Expected %d shakes, detected %d" % [iterations, shake_detected] if not passed else ""
	})

func test_no_offset_drift():
	print("\n🧪 Test: No permanent offset drift")
	test_data["initial_pos"] = world.position
	test_data["miss_count"] = 0
	print("  Initial world position:", test_data["initial_pos"])
	frame_count = 0

func test_no_offset_drift_check():
	var initial_pos = test_data["initial_pos"]
	var final_pos = world.position
	print("  Final world position:", final_pos)
	
	var drift = final_pos.distance_to(initial_pos)
	var passed = drift < 5.0
	
	test_results.append({
		"name": "No permanent offset drift",
		"passed": passed,
		"reason": "Expected 0 drift, got %.2fpx" % drift if not passed else ""
	})

func test_no_shake_when_paused():
	print("\n🧪 Test: No shake while paused")
	game_manager.toggle_pause()
	test_data["pos_before_pause"] = world.position
	game_manager.spawn_miss_juice(Vector2(360, 600))
	frame_count = 0

func test_no_shake_when_paused_check():
	var pos_before = test_data["pos_before_pause"]
	var pos_after = world.position
	var passed = pos_before == pos_after
	
	# Unpause
	game_manager.toggle_pause()
	
	test_results.append({
		"name": "No shake while paused",
		"passed": passed,
		"reason": "Position changed while paused: %s -> %s" % [pos_before, pos_after] if not passed else ""
	})

func test_no_shake_when_game_over():
	print("\n🧪 Test: No shake during game over")
	game_manager.game_over(false)
	test_data["pos_before_gameover"] = world.position
	game_manager.spawn_miss_juice(Vector2(360, 600))
	frame_count = 0

func test_no_shake_when_game_over_check():
	var pos_before = test_data["pos_before_gameover"]
	var pos_after = world.position
	var passed = pos_before == pos_after
	
	test_results.append({
		"name": "No shake during game over",
		"passed": passed,
		"reason": "Position changed during game over: %s -> %s" % [pos_before, pos_after] if not passed else ""
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
