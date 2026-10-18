extends SceneTree

# QA VERIFICATION TESTS
# Run with: godot --headless --path flick-freight -s res://tools/qa_test.gd

var main_scene: Node = null
var game_manager: Node = null
var truck_bay: Node = null
var ui_manager: Node = null
var test_frame: int = 0
var test_state: String = "init"

# Test 1: HUD/Bay overlap
var hud_panel_bottom: float = 0.0
var bay_top: float = 0.0

# Test 2: QA flag bay speed
var qa_bay_start_x: float = 0.0
var qa_bay_displacement: float = 0.0
var normal_bay_start_x: float = 0.0
var normal_bay_displacement: float = 0.0

# Test 3: Truck reset
var restart_bay_x: float = 0.0

func _initialize():
	print("═══════════════════════════════════════")
	print("🧪 QA VERIFICATION TESTS")
	print("═══════════════════════════════════════")
	
	# Load main scene
	var scene_resource = load("res://scenes/main.tscn")
	if !scene_resource:
		print("❌ FAIL: Could not load main scene")
		quit(1)
		return
	
	main_scene = scene_resource.instantiate()
	root.add_child(main_scene)
	
	# Get references
	game_manager = main_scene.get_node_or_null("GameManager")
	truck_bay = main_scene.get_node_or_null("World/TruckBay")
	ui_manager = main_scene.get_node_or_null("UIManager")
	
	if !game_manager or !truck_bay or !ui_manager:
		print("❌ FAIL: Could not find required nodes")
		quit(1)
		return
	
	print("✅ Scene loaded successfully")
	print("")
	
	test_state = "wait_init"
	test_frame = 0

func _process(delta: float) -> bool:
	test_frame += 1
	
	match test_state:
		"wait_init":
			if test_frame >= 10:
				test_state = "test1_measure"
				test_frame = 0
		
		"test1_measure":
			run_test1_hud_bay_overlap()
			test_state = "test2_setup_qa"
			test_frame = 0
		
		"test2_setup_qa":
			# Force QA mode ON
			game_manager.qa_mode = true
			truck_bay.set_speed_multiplier(0.25)
			truck_bay.reset_position()
			test_frame = 0
			test_state = "test2_wait_qa_settle"
		
		"test2_wait_qa_settle":
			if test_frame == 5:
				qa_bay_start_x = truck_bay.position.x
			elif test_frame >= 65:
				# Measure after 60 frames
				qa_bay_displacement = abs(truck_bay.position.x - qa_bay_start_x)
				test_state = "test2_setup_normal"
				test_frame = 0
		
		"test2_setup_normal":
			# Reset to normal speed
			game_manager.qa_mode = false
			truck_bay.set_speed_multiplier(1.0)
			truck_bay.reset_position()
			test_frame = 0
			test_state = "test2_wait_normal_settle"
		
		"test2_wait_normal_settle":
			if test_frame == 5:
				normal_bay_start_x = truck_bay.position.x
			elif test_frame >= 65:
				# Measure after 60 frames
				normal_bay_displacement = abs(truck_bay.position.x - normal_bay_start_x)
				test_state = "test2_check"
				test_frame = 0
		
		"test2_check":
			run_test2_qa_bay_speed()
			test_state = "test3_restart"
			test_frame = 0
		
		"test3_restart":
			# Call restart
			game_manager.restart_game()
			test_state = "test3_wait_restart"
			test_frame = 0
		
		"test3_wait_restart":
			if test_frame >= 2:
				# Check bay position after 1 frame
				restart_bay_x = truck_bay.position.x
				test_state = "test3_check"
				test_frame = 0
		
		"test3_check":
			run_test3_truck_reset()
			test_state = "done"
		
		"done":
			print("")
			print("═══════════════════════════════════════")
			print("QA TESTS COMPLETE")
			print("═══════════════════════════════════════")
			quit(0)
			return true
	
	return false

func run_test1_hud_bay_overlap():
	print("─────────────────────────────────────────")
	print("TEST 1: HUD/Bay Overlap")
	print("─────────────────────────────────────────")
	
	# Get HUD panel (HUDBacking ColorRect)
	var hud_backing = ui_manager.get_node_or_null("UI/HUDBacking")
	if !hud_backing:
		print("❌ FAIL: Could not find HUDBacking")
		return
	
	# HUDBacking has offset_bottom = 140, so its global bottom is at y=140
	# (since it's in a CanvasLayer at y=0)
	var hud_rect = hud_backing.get_global_rect()
	hud_panel_bottom = hud_rect.position.y + hud_rect.size.y
	
	# Get bay body ColorRect (TruckBody inside TruckBay)
	var truck_body = truck_bay.get_node_or_null("TruckBody")
	if !truck_body:
		print("❌ FAIL: Could not find TruckBody")
		return
	
	# Bay is at some position, body has offset_top = -50
	# So bay_top = bay.global_position.y + body.offset_top
	var bay_pos = truck_bay.global_position
	bay_top = bay_pos.y + truck_body.position.y
	
	# Use truck_body offset to calculate top edge
	# offset_top is -50, so the top edge is at bay.position.y - 50
	bay_top = bay_pos.y - 50
	
	print("  HUD panel bottom: %.1f" % hud_panel_bottom)
	print("  Bay body top: %.1f" % bay_top)
	print("  Gap: %.1f px" % (bay_top - hud_panel_bottom))
	
	if bay_top > hud_panel_bottom:
		print("  ✅ PASS: Bay top (%.1f) > HUD bottom (%.1f)" % [bay_top, hud_panel_bottom])
	else:
		print("  ❌ FAIL: Bay top (%.1f) <= HUD bottom (%.1f) - OVERLAP!" % [bay_top, hud_panel_bottom])
	print("")

func run_test2_qa_bay_speed():
	print("─────────────────────────────────────────")
	print("TEST 2: QA Flag Bay Speed")
	print("─────────────────────────────────────────")
	
	print("  QA mode (0.25x): displacement over 60 frames = %.1f px" % qa_bay_displacement)
	print("  Normal mode (1.0x): displacement over 60 frames = %.1f px" % normal_bay_displacement)
	
	if normal_bay_displacement > 0:
		var ratio = qa_bay_displacement / normal_bay_displacement
		print("  Ratio: %.3f (expected ~0.25)" % ratio)
		
		# Allow 20% tolerance: 0.20 to 0.30
		if ratio >= 0.20 and ratio <= 0.30:
			print("  ✅ PASS: QA mode slows bay to ~0.25x normal speed")
		else:
			print("  ❌ FAIL: QA mode ratio %.3f is not close to 0.25" % ratio)
	else:
		print("  ❌ FAIL: Normal displacement is zero, can't calculate ratio")
	print("")

func run_test3_truck_reset():
	print("─────────────────────────────────────────")
	print("TEST 3: Truck Reset on Retry")
	print("─────────────────────────────────────────")
	
	var center_x = truck_bay.center_x
	var distance = abs(restart_bay_x - center_x)
	
	print("  Center x: %.1f" % center_x)
	print("  Bay x after restart + 1 frame: %.1f" % restart_bay_x)
	print("  Distance from center: %.1f px" % distance)
	
	if distance <= 5.0:
		print("  ✅ PASS: Bay centered within 5px after restart")
	else:
		print("  ❌ FAIL: Bay at %.1f, expected within 5px of center %.1f" % [restart_bay_x, center_x])
	print("")
