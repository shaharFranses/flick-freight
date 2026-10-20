extends SceneTree

# Layout test for Flick Freight
# Verifies no HUD elements overlap and all are within viewport bounds

var main_scene: Node = null
var ui_manager: Node = null
var game_manager: Node = null
var test_results: Array = []

func _init():
	print("═══════════════════════════════════════")
	print("🧪 LAYOUT TEST STARTING")
	print("═══════════════════════════════════════")
	
	# Load main scene
	var packed_scene = load("res://scenes/main.tscn")
	if not packed_scene:
		push_error("❌ FAILED TO LOAD main.tscn")
		quit(1)
		return
	
	main_scene = packed_scene.instantiate()
	root.add_child(main_scene)
	
	# Get managers
	ui_manager = main_scene.get_node_or_null("UIManager")
	game_manager = main_scene.get_node_or_null("GameManager")
	
	if not ui_manager or not game_manager:
		push_error("❌ FAILED TO FIND managers")
		quit(1)
		return
	
	print("✅ Scene loaded successfully")
	print("")

func _process(_delta: float) -> bool:
	# Wait a few frames for scene to initialize
	if Engine.get_process_frames() < 10:
		return false
	
	# Run tests
	test_hud_no_overlap()
	test_elements_in_viewport()
	test_gameover_layout()
	
	# Print summary
	print_summary()
	return true

func test_hud_no_overlap():
	print("─────────────────────────────────────────")
	print("TEST 1: HUD Elements No Overlap")
	print("─────────────────────────────────────────")
	
	var ui = ui_manager.get_node("UI")
	var elements = []
	
	# Collect all HUD elements with their rects
	var score_plate = ui.get_node_or_null("ScorePlate")
	if score_plate:
		elements.append({"name": "ScorePlate", "rect": score_plate.get_global_rect()})
	
	var loads_label = ui.get_node_or_null("LoadsLabel")
	if loads_label:
		elements.append({"name": "LoadsLabel", "rect": loads_label.get_global_rect()})
	
	var timer_label = ui.get_node_or_null("TimerLabel")
	if timer_label:
		elements.append({"name": "TimerLabel", "rect": timer_label.get_global_rect()})
	
	var streak_plate = ui.get_node_or_null("StreakPlate")
	if streak_plate:
		elements.append({"name": "StreakPlate", "rect": streak_plate.get_global_rect()})
	
	var pause_plate = ui.get_node_or_null("PausePlate")
	if pause_plate:
		elements.append({"name": "PausePlate", "rect": pause_plate.get_global_rect()})
	
	var mute_plate = ui.get_node_or_null("MutePlate")
	if mute_plate:
		elements.append({"name": "MutePlate", "rect": mute_plate.get_global_rect()})
	
	var qa_badge = ui.get_node_or_null("%QABadge")
	if qa_badge and qa_badge.visible:
		elements.append({"name": "QABadge", "rect": qa_badge.get_global_rect()})
	
	# Check NEXT preview if exists
	if game_manager.next_preview != null and is_instance_valid(game_manager.next_preview):
		var next_bounds = get_preview_bounds(game_manager.next_preview)
		if next_bounds:
			elements.append({"name": "NEXTPreview", "rect": next_bounds})
	
	# Check CURRENT package chip if exists
	if game_manager.current_package != null and is_instance_valid(game_manager.current_package):
		var chip = game_manager.current_package.get_node_or_null("CurrentChip")
		if chip:
			var chip_rect = get_node_global_rect(chip, game_manager.current_package)
			if chip_rect:
				elements.append({"name": "CURRENTChip", "rect": chip_rect})
	
	print("  Found %d elements to check" % elements.size())
	
	# Check for overlaps
	var overlaps_found = false
	for i in range(elements.size()):
		for j in range(i + 1, elements.size()):
			var elem_a = elements[i]
			var elem_b = elements[j]
			
			if rects_intersect(elem_a.rect, elem_b.rect):
				print("  ❌ OVERLAP: %s intersects %s" % [elem_a.name, elem_b.name])
				print("    %s: %s" % [elem_a.name, rect_to_string(elem_a.rect)])
				print("    %s: %s" % [elem_b.name, rect_to_string(elem_b.rect)])
				overlaps_found = true
	
	if overlaps_found:
		test_results.append({"name": "HUD no overlap", "passed": false, "reason": "Elements overlap"})
		print("  ❌ FAIL: HUD elements overlap")
	else:
		test_results.append({"name": "HUD no overlap", "passed": true, "reason": ""})
		print("  ✅ PASS: No HUD overlaps")
	
	print("")

func test_elements_in_viewport():
	print("─────────────────────────────────────────")
	print("TEST 2: Elements Within Viewport")
	print("─────────────────────────────────────────")
	
	var viewport_rect = Rect2(0, 0, 720, 1280)
	var ui = ui_manager.get_node("UI")
	var out_of_bounds = false
	
	# Check each element
	var elements_to_check = [
		"ScorePlate", "LoadsLabel", "TimerLabel", "StreakPlate",
		"PausePlate", "MutePlate"
	]
	
	for elem_name in elements_to_check:
		var elem = ui.get_node_or_null(elem_name)
		if elem:
			var rect = elem.get_global_rect()
			if not viewport_rect.encloses(rect):
				print("  ❌ OUT OF BOUNDS: %s at %s" % [elem_name, rect_to_string(rect)])
				out_of_bounds = true
	
	# Check buttons are >= 48px
	var pause_plate = ui.get_node_or_null("PausePlate")
	var mute_plate = ui.get_node_or_null("MutePlate")
	
	var button_size_ok = true
	if pause_plate:
		var rect = pause_plate.get_global_rect()
		if rect.size.x < 48 or rect.size.y < 48:
			print("  ❌ Pause button too small: %.0fx%.0f (min 48x48)" % [rect.size.x, rect.size.y])
			button_size_ok = false
	
	if mute_plate:
		var rect = mute_plate.get_global_rect()
		if rect.size.x < 48 or rect.size.y < 48:
			print("  ❌ Mute button too small: %.0fx%.0f (min 48x48)" % [rect.size.x, rect.size.y])
			button_size_ok = false
	
	# Check buttons outside bay x-sweep (180-540)
	var bay_sweep_ok = true
	if pause_plate:
		var rect = pause_plate.get_global_rect()
		if rect.position.x >= 180 and rect.position.x + rect.size.x <= 540:
			print("  ❌ Pause button inside bay x-sweep (180-540)")
			bay_sweep_ok = false
	
	if mute_plate:
		var rect = mute_plate.get_global_rect()
		if rect.position.x >= 180 and rect.position.x + rect.size.x <= 540:
			print("  ❌ Mute button inside bay x-sweep (180-540)")
			bay_sweep_ok = false
	
	var all_ok = not out_of_bounds and button_size_ok and bay_sweep_ok
	
	if all_ok:
		test_results.append({"name": "Elements in viewport", "passed": true, "reason": ""})
		print("  ✅ PASS: All elements within viewport and sized correctly")
	else:
		test_results.append({"name": "Elements in viewport", "passed": false, "reason": "Elements out of bounds or wrong size"})
		print("  ❌ FAIL: Layout issues found")
	
	print("")

func test_gameover_layout():
	print("─────────────────────────────────────────")
	print("TEST 3: Game Over Layout")
	print("─────────────────────────────────────────")
	
	# Trigger game over
	game_manager.is_game_over = true
	game_manager.game_over(false)
	
	# Wait a frame (can't use await in SceneTree, check immediately)
	
	var ui = ui_manager.get_node("UI")
	var game_over_panel = ui.get_node_or_null("GameOverPanel")
	
	if not game_over_panel or not game_over_panel.visible:
		test_results.append({"name": "Game over layout", "passed": false, "reason": "Game over panel not visible"})
		print("  ❌ FAIL: Game over panel not visible")
		print("")
		return
	
	# Check NEXT/CURRENT are hidden
	var next_hidden = game_manager.next_preview == null or not is_instance_valid(game_manager.next_preview) or not game_manager.next_preview.visible
	var current_hidden = game_manager.current_package == null or not is_instance_valid(game_manager.current_package) or not game_manager.current_package.visible
	
	print("  NEXT hidden: %s" % next_hidden)
	print("  CURRENT hidden: %s" % current_hidden)
	
	if next_hidden and current_hidden:
		test_results.append({"name": "Game over layout", "passed": true, "reason": ""})
		print("  ✅ PASS: NEXT/CURRENT hidden on game over")
	else:
		test_results.append({"name": "Game over layout", "passed": false, "reason": "NEXT/CURRENT not hidden"})
		print("  ❌ FAIL: NEXT/CURRENT should be hidden on game over")
	
	print("")

func get_preview_bounds(preview: Node2D) -> Rect2:
	# Calculate bounds of NEXT preview including all children
	var min_x = preview.position.x
	var max_x = preview.position.x
	var min_y = preview.position.y
	var max_y = preview.position.y
	
	for child in preview.get_children():
		if child is Control:
			var rect = child.get_global_rect()
			min_x = min(min_x, rect.position.x)
			max_x = max(max_x, rect.position.x + rect.size.x)
			min_y = min(min_y, rect.position.y)
			max_y = max(max_y, rect.position.y + rect.size.y)
		elif child is ColorRect:
			var pos = preview.position + child.position
			min_x = min(min_x, pos.x)
			max_x = max(max_x, pos.x + child.size.x)
			min_y = min(min_y, pos.y)
			max_y = max(max_y, pos.y + child.size.y)
	
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func get_node_global_rect(node: Node, package: Node2D) -> Rect2:
	# For Label nodes on packages, calculate global rect
	if node is Label:
		var global_pos = package.global_position + node.position
		return Rect2(global_pos, Vector2(70, 20))  # CurrentChip size
	return Rect2()

func rects_intersect(a: Rect2, b: Rect2) -> bool:
	return a.intersects(b, true)

func rect_to_string(rect: Rect2) -> String:
	return "x:%.0f-%.0f y:%.0f-%.0f (%.0fx%.0f)" % [
		rect.position.x, rect.position.x + rect.size.x,
		rect.position.y, rect.position.y + rect.size.y,
		rect.size.x, rect.size.y
	]

func print_summary():
	print("═══════════════════════════════════════")
	print("LAYOUT TEST SUMMARY:")
	var passed = 0
	var failed = 0
	for result in test_results:
		if result.passed:
			passed += 1
			print("  ✅ " + result.name)
		else:
			failed += 1
			print("  ❌ " + result.name + ": " + result.reason)
	
	print("")
	print("Total: %d passed, %d failed" % [passed, failed])
	print("═══════════════════════════════════════")
	
	if failed > 0:
		quit(1)
	else:
		quit(0)
