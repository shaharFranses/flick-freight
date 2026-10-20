extends SceneTree

# Test for QA ITEM 1: Hit flash must be localized, not full-screen

var main_scene: Node = null
var game_manager: Node = null
var world: Node2D = null
var ui_manager: Node = null
var test_results: Array = []

func _init():
	print("═══════════════════════════════════════")
	print("🧪 HIT FLASH LOCALIZATION TEST")
	print("═══════════════════════════════════════")
	
	# Load main scene
	var packed_scene = load("res://scenes/main.tscn")
	if not packed_scene:
		push_error("❌ FAILED TO LOAD main.tscn")
		quit(1)
		return
	
	main_scene = packed_scene.instantiate()
	root.add_child(main_scene)
	
	# Get nodes
	game_manager = main_scene.get_node_or_null("GameManager")
	world = main_scene.get_node_or_null("World")
	ui_manager = main_scene.get_node_or_null("UIManager")
	
	if not game_manager or not world or not ui_manager:
		push_error("❌ FAILED TO FIND required nodes")
		quit(1)
		return
	
	print("✅ Scene loaded successfully")

func _process(_delta: float) -> bool:
	# Run test once
	if not test_results.is_empty():
		return false
	
	var test_done = test_hit_flash_localized()
	
	if test_done:
		# Print results
		print("═══════════════════════════════════════")
		print("📊 TEST RESULTS")
		print("═══════════════════════════════════════")
		
		var passed = 0
		var failed = 0
		for result in test_results:
			if result.passed:
				passed += 1
				print("✅", result.name)
			else:
				failed += 1
				print("❌", result.name, ":", result.reason)
		
		print("═══════════════════════════════════════")
		print("PASSED:", passed, "FAILED:", failed)
		print("═══════════════════════════════════════")
		
		quit(0 if failed == 0 else 1)
	
	return false

func test_hit_flash_localized():
	print("\n🧪 Test: Hit flash is localized (not full-screen)")
	
	# Get background color before hit
	var background = world.get_node_or_null("Background")
	if not background:
		test_results.append({
			"name": "Hit flash localized",
			"passed": false,
			"reason": "Background node not found"
		})
		return
	
	var bg_color_before = background.color
	print("  Background color before:", bg_color_before)
	
	# Count ColorRects in World before hit
	var rects_before = count_color_rects_in_world()
	print("  ColorRects in World before:", rects_before)
	
	# Trigger hit flash
	var hit_pos = Vector2(360, 200)
	game_manager.spawn_hit_juice(hit_pos, 1, Color(1, 1, 1))
	
	# Flash is added synchronously, check immediately
	# Count ColorRects after
	var rects_after = count_color_rects_in_world()
	print("  ColorRects in World after:", rects_after)
	
	# Check that background color hasn't changed
	var bg_color_after = background.color
	print("  Background color after:", bg_color_after)
	
	var bg_unchanged = bg_color_before == bg_color_after
	
	# Find flash-like ColorRects that were added (comparing to baseline)
	var new_flash_rects = find_new_flash_rects_in_world()
	print("  New flash-like ColorRects:", new_flash_rects.size())
	for rect in new_flash_rects:
		print("    - Size:", rect.size, "Color:", rect.color, "Alpha:", rect.color.a)
	
	# Check World and root modulate
	var world_modulate = world.modulate
	var world_self_modulate = world.self_modulate
	print("  World modulate:", world_modulate)
	print("  World self_modulate:", world_self_modulate)
	
	# Check if any large (>200x200) flash was added
	var has_large_flash = false
	for rect in new_flash_rects:
		if rect.size.x > 200 or rect.size.y > 200:
			has_large_flash = true
			break
	
	# Test passes if:
	# 1. Background color unchanged
	# 2. No large (>200x200) new ColorRects
	# 3. World modulate is default (1,1,1,1)
	var passed = bg_unchanged and not has_large_flash and world_modulate == Color(1, 1, 1, 1)
	
	var reason = ""
	if not bg_unchanged:
		reason = "Background color changed from %s to %s" % [bg_color_before, bg_color_after]
	elif has_large_flash:
		reason = "Found large (>200x200) new ColorRect (full-screen flash)"
	elif world_modulate != Color(1, 1, 1, 1):
		reason = "World modulate is %s (expected (1,1,1,1))" % world_modulate
	
	test_results.append({
		"name": "Hit flash localized",
		"passed": passed,
		"reason": reason
	})
	
	return true  # Test complete

func count_color_rects_in_world() -> int:
	var count = 0
	for child in world.get_children():
		if child is ColorRect:
			count += 1
		count += count_rects_recursive(child)
	return count

func count_rects_recursive(node: Node) -> int:
	var count = 0
	for child in node.get_children():
		if child is ColorRect:
			count += 1
		count += count_rects_recursive(child)
	return count

func find_new_flash_rects_in_world() -> Array:
	# Find ColorRects that have "flash" in their name or are temporary (not in scene tree initially)
	var new_rects = []
	for child in world.get_children():
		if child is ColorRect:
			# Skip known scene elements
			if child.name in ["Background", "DockFloor"]:
				continue
			new_rects.append(child)
		new_rects.append_array(find_new_rects_recursive(child))
	return new_rects

func find_new_rects_recursive(node: Node) -> Array:
	var new_rects = []
	for child in node.get_children():
		if child is ColorRect:
			# Skip known elements (floor lines, truck parts)
			if not (child.name in ["TruckBody", "TruckCab", "CabWindow", "LoadingBedRim", "LeftSideRim", "RightSideRim", "BayOpening", "Line1", "Line2", "Line3", "Line4"]):
				new_rects.append(child)
		new_rects.append_array(find_new_rects_recursive(child))
	return new_rects
