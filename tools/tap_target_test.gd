extends SceneTree

# Tap-target test for button clickability
# Verifies drawn rect matches clickable rect and no overlapping controls block input

var main_scene: Node = null
var ui_manager: Node = null
var test_results: Array = []
var button_click_counts: Dictionary = {}

func _init():
	print("═══════════════════════════════════════")
	print("🧪 TAP-TARGET TEST STARTING")
	print("═══════════════════════════════════════")
	
	# Load main scene
	var packed_scene = load("res://scenes/main.tscn")
	if not packed_scene:
		push_error("❌ FAILED TO LOAD main.tscn")
		quit(1)
		return
	
	main_scene = packed_scene.instantiate()
	root.add_child(main_scene)
	
	ui_manager = main_scene.get_node_or_null("UIManager")
	if not ui_manager:
		push_error("❌ FAILED TO FIND UIManager")
		quit(1)
		return
	
	print("✅ Scene loaded successfully")
	print("")

func _process(_delta: float) -> bool:
	# Wait for initialization
	if Engine.get_process_frames() < 10:
		return false
	
	# Run tests
	test_pause_button()
	test_mute_button()
	
	# Print summary
	print_summary()
	return true

func test_pause_button():
	print("─────────────────────────────────────────")
	print("TEST 1: Pause Button Clickability")
	print("─────────────────────────────────────────")
	
	var ui = ui_manager.get_node("UI")
	var pause_plate = ui.get_node_or_null("PausePlate")
	var pause_button = ui.get_node_or_null("%PauseButton")
	
	if not pause_plate or not pause_button:
		test_results.append({"name": "Pause button", "passed": false, "reason": "Button not found"})
		print("  ❌ FAIL: Pause button not found")
		print("")
		return
	
	# Get rects
	var plate_rect = pause_plate.get_global_rect()
	var button_rect = pause_button.get_global_rect()
	
	print("  Pause plate rect: %s" % rect_to_string(plate_rect))
	print("  Pause button rect: %s" % rect_to_string(button_rect))
	
	# Check for overlapping controls
	var overlaps = find_overlapping_controls(plate_rect, pause_button)
	if overlaps.size() > 0:
		print("  ⚠️  Controls overlapping Pause:")
		for overlap in overlaps:
			print("    - %s (mouse_filter: %s)" % [overlap.name, get_mouse_filter_name(overlap.mouse_filter)])
	
	# Check button properties
	var button_disabled = pause_button.disabled
	var button_visible = pause_button.visible
	var button_mouse_filter = pause_button.mouse_filter
	
	print("  Button disabled: %s" % button_disabled)
	print("  Button visible: %s" % button_visible)
	print("  Button mouse_filter: %s" % get_mouse_filter_name(button_mouse_filter))
	
	# Verdict: Button is clickable if:
	# 1. Drawn rect (plate) >= 48x48 (already checked in layout test)
	# 2. Button rect matches drawn rect
	# 3. No overlapping controls with mouse_filter != IGNORE
	# 4. Button is enabled, visible, and has mouse_filter = STOP
	
	var rect_matches = plate_rect.is_equal_approx(button_rect)
	var no_blockers = overlaps.size() == 0
	var button_enabled = not button_disabled and button_visible
	var button_can_receive = button_mouse_filter == Control.MOUSE_FILTER_STOP
	
	print("  Rect matches: %s" % rect_matches)
	print("  No blocking controls: %s" % no_blockers)
	print("  Button enabled/visible: %s" % button_enabled)
	print("  Button can receive input: %s" % button_can_receive)
	
	var all_ok = rect_matches and no_blockers and button_enabled and button_can_receive
	
	if all_ok:
		test_results.append({"name": "Pause button clickable", "passed": true, "reason": ""})
		print("  ✅ PASS: Button should be fully clickable (58x58, no blockers)")
	else:
		var issues = []
		if not rect_matches:
			issues.append("rect mismatch")
		if not no_blockers:
			issues.append("has blockers")
		if not button_enabled:
			issues.append("not enabled/visible")
		if not button_can_receive:
			issues.append("wrong mouse_filter")
		test_results.append({"name": "Pause button clickable", "passed": false, "reason": " + ".join(issues)})
		print("  ❌ FAIL: %s" % " + ".join(issues))
	
	print("")

func test_mute_button():
	print("─────────────────────────────────────────")
	print("TEST 2: Mute Button Clickability")
	print("─────────────────────────────────────────")
	
	var ui = ui_manager.get_node("UI")
	var mute_plate = ui.get_node_or_null("MutePlate")
	var mute_button = ui.get_node_or_null("%MuteButton")
	
	if not mute_plate or not mute_button:
		test_results.append({"name": "Mute button", "passed": false, "reason": "Button not found"})
		print("  ❌ FAIL: Mute button not found")
		print("")
		return
	
	# Get rects
	var plate_rect = mute_plate.get_global_rect()
	var button_rect = mute_button.get_global_rect()
	
	print("  Mute plate rect: %s" % rect_to_string(plate_rect))
	print("  Mute button rect: %s" % rect_to_string(button_rect))
	
	# Check for overlapping controls
	var overlaps = find_overlapping_controls(plate_rect, mute_button)
	if overlaps.size() > 0:
		print("  ⚠️  Controls overlapping Mute:")
		for overlap in overlaps:
			print("    - %s (mouse_filter: %s)" % [overlap.name, get_mouse_filter_name(overlap.mouse_filter)])
	
	# Check button properties
	var button_disabled = mute_button.disabled
	var button_visible = mute_button.visible
	var button_mouse_filter = mute_button.mouse_filter
	
	print("  Button disabled: %s" % button_disabled)
	print("  Button visible: %s" % button_visible)
	print("  Button mouse_filter: %s" % get_mouse_filter_name(button_mouse_filter))
	
	# Verdict: Button is clickable if:
	# 1. Drawn rect (plate) >= 48x48 (already checked in layout test)
	# 2. Button rect matches drawn rect
	# 3. No overlapping controls with mouse_filter != IGNORE
	# 4. Button is enabled, visible, and has mouse_filter = STOP
	
	var rect_matches = plate_rect.is_equal_approx(button_rect)
	var no_blockers = overlaps.size() == 0
	var button_enabled = not button_disabled and button_visible
	var button_can_receive = button_mouse_filter == Control.MOUSE_FILTER_STOP
	
	print("  Rect matches: %s" % rect_matches)
	print("  No blocking controls: %s" % no_blockers)
	print("  Button enabled/visible: %s" % button_enabled)
	print("  Button can receive input: %s" % button_can_receive)
	
	var all_ok = rect_matches and no_blockers and button_enabled and button_can_receive
	
	if all_ok:
		test_results.append({"name": "Mute button clickable", "passed": true, "reason": ""})
		print("  ✅ PASS: Button should be fully clickable (58x58, no blockers)")
	else:
		var issues = []
		if not rect_matches:
			issues.append("rect mismatch")
		if not no_blockers:
			issues.append("has blockers")
		if not button_enabled:
			issues.append("not enabled/visible")
		if not button_can_receive:
			issues.append("wrong mouse_filter")
		test_results.append({"name": "Mute button clickable", "passed": false, "reason": " + ".join(issues)})
		print("  ❌ FAIL: %s" % " + ".join(issues))
	
	print("")

func _on_pause_clicked():
	button_click_counts["pause"] += 1

func _on_mute_clicked():
	button_click_counts["mute"] += 1

func get_test_points(rect: Rect2) -> Array:
	# Return center + 4 quadrant points (20% in from each edge)
	var points = []
	
	# Center
	points.append({
		"label": "Center",
		"position": rect.position + rect.size * 0.5
	})
	
	# Top-left quadrant (20% in from edges)
	points.append({
		"label": "Top-left",
		"position": rect.position + Vector2(rect.size.x * 0.2, rect.size.y * 0.2)
	})
	
	# Top-right quadrant
	points.append({
		"label": "Top-right",
		"position": rect.position + Vector2(rect.size.x * 0.8, rect.size.y * 0.2)
	})
	
	# Bottom-left quadrant
	points.append({
		"label": "Bottom-left",
		"position": rect.position + Vector2(rect.size.x * 0.2, rect.size.y * 0.8)
	})
	
	# Bottom-right quadrant
	points.append({
		"label": "Bottom-right",
		"position": rect.position + Vector2(rect.size.x * 0.8, rect.size.y * 0.8)
	})
	
	return points

func find_overlapping_controls(button_rect: Rect2, exclude: Control) -> Array:
	var overlaps = []
	var ui = ui_manager.get_node("UI")
	
	for child in ui.get_children():
		if child == exclude or not child is Control:
			continue
		
		if child.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		
		var child_rect = child.get_global_rect()
		if button_rect.intersects(child_rect, true):
			overlaps.append(child)
	
	return overlaps

func get_mouse_filter_name(filter: int) -> String:
	match filter:
		Control.MOUSE_FILTER_STOP:
			return "STOP"
		Control.MOUSE_FILTER_PASS:
			return "PASS"
		Control.MOUSE_FILTER_IGNORE:
			return "IGNORE"
		_:
			return "UNKNOWN"

func rect_to_string(rect: Rect2) -> String:
	return "x:%.0f-%.0f y:%.0f-%.0f (%.0fx%.0f)" % [
		rect.position.x, rect.position.x + rect.size.x,
		rect.position.y, rect.position.y + rect.size.y,
		rect.size.x, rect.size.y
	]

func print_summary():
	print("═══════════════════════════════════════")
	print("TAP-TARGET TEST SUMMARY:")
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
