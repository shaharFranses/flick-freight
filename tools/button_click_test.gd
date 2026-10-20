extends SceneTree

# Button click test with REAL viewport events
# Sends actual InputEventMouseButton through viewport at a 3x3 grid per button

var main_scene: Node = null
var ui_manager: Node = null
var game_manager: Node = null
var viewport: Viewport = null
var test_results: Array = []
var click_counts: Dictionary = {"pause": 0, "mute": 0}

func _init():
	print("═══════════════════════════════════════")
	print("🧪 BUTTON CLICK TEST (REAL EVENTS)")
	print("═══════════════════════════════════════")
	
	# Get viewport
	viewport = root
	
	# Load main scene
	var packed_scene = load("res://scenes/main.tscn")
	if not packed_scene:
		push_error("❌ FAILED TO LOAD main.tscn")
		quit(1)
		return
	
	main_scene = packed_scene.instantiate()
	root.add_child(main_scene)
	
	ui_manager = main_scene.get_node_or_null("UIManager")
	game_manager = main_scene.get_node_or_null("GameManager")
	
	if not ui_manager or not game_manager:
		push_error("❌ FAILED TO FIND managers")
		quit(1)
		return
	
	print("✅ Scene loaded successfully")
	print("")

func _process(_delta: float) -> bool:
	if Engine.get_process_frames() < 10:
		return false
	
	# Connect button handlers
	var pause_button = ui_manager.get_node_or_null("%PauseButton")
	var mute_button = ui_manager.get_node_or_null("%MuteButton")
	
	if pause_button:
		pause_button.pressed.connect(_on_pause_clicked)
	if mute_button:
		mute_button.pressed.connect(_on_mute_clicked)
	
	# Analyze button structure
	analyze_pause_structure()
	analyze_mute_structure()
	
	# Test while unpaused
	print("─────────────────────────────────────────")
	print("TESTING WHILE UNPAUSED")
	print("─────────────────────────────────────────")
	test_pause_button_clicks(false)
	test_mute_button_clicks(false)
	
	# Test while paused
	game_manager.toggle_pause()
	print("─────────────────────────────────────────")
	print("TESTING WHILE PAUSED (Resume)")
	print("─────────────────────────────────────────")
	test_pause_button_clicks(true)
	test_mute_button_clicks(true)
	
	print_summary()
	return true

func analyze_pause_structure():
	print("─────────────────────────────────────────")
	print("PAUSE BUTTON STRUCTURE ANALYSIS")
	print("─────────────────────────────────────────")
	
	var ui = ui_manager.get_node("UI")
	var pause_button = ui.get_node_or_null("%PauseButton")
	
	if not pause_button:
		print("  ❌ Pause button not found")
		return
	
	var button_rect = pause_button.get_global_rect()
	var button_center = button_rect.get_center()
	
	print("  Button rect: %s" % rect_to_string(button_rect))
	print("  Button center: (%.1f, %.1f)" % [button_center.x, button_center.y])
	print("  Button mouse_filter: %s" % get_mouse_filter_name(pause_button.mouse_filter))
	print("  Button disabled: %s" % pause_button.disabled)
	
	var pause_icon = pause_button.get_node_or_null("PauseIcon")
	if pause_icon:
		print("  PauseIcon mouse_filter: %s" % get_mouse_filter_name(pause_icon.mouse_filter))
		var bar1 = pause_icon.get_node_or_null("Bar1")
		var bar2 = pause_icon.get_node_or_null("Bar2")
		if bar1:
			print("  Bar1 mouse_filter: %s" % get_mouse_filter_name(bar1.mouse_filter))
		if bar2:
			print("  Bar2 mouse_filter: %s" % get_mouse_filter_name(bar2.mouse_filter))
	
	print("")
	print("  Nodes whose rect contains button center:")
	
	var containing_nodes = find_nodes_containing_point(ui, button_center, pause_button)
	for node_info in containing_nodes:
		print("    - %s (z:%d, filter:%s, mode:%s)" % [
			node_info.path,
			node_info.z_index,
			get_mouse_filter_name(node_info.mouse_filter),
			get_process_mode_name(node_info.process_mode)
		])
	
	print("")

func analyze_mute_structure():
	print("─────────────────────────────────────────")
	print("MUTE BUTTON STRUCTURE ANALYSIS")
	print("─────────────────────────────────────────")
	
	var ui = ui_manager.get_node("UI")
	var mute_button = ui.get_node_or_null("%MuteButton")
	
	if not mute_button:
		print("  ❌ Mute button not found")
		return
	
	var button_rect = mute_button.get_global_rect()
	var button_center = button_rect.get_center()
	
	print("  Button rect: %s" % rect_to_string(button_rect))
	print("  Button center: (%.1f, %.1f)" % [button_center.x, button_center.y])
	print("  Button mouse_filter: %s" % get_mouse_filter_name(mute_button.mouse_filter))
	print("  Button disabled: %s" % mute_button.disabled)
	
	var speaker_icon = mute_button.get_node_or_null("SpeakerIcon")
	if speaker_icon:
		print("  SpeakerIcon mouse_filter: %s" % get_mouse_filter_name(speaker_icon.mouse_filter))
		for child_name in ["Base", "Cone", "Wave1", "MuteSlash"]:
			var child = speaker_icon.get_node_or_null(child_name)
			if child:
				print("  %s mouse_filter: %s" % [child_name, get_mouse_filter_name(child.mouse_filter)])
	
	print("")
	print("  Nodes whose rect contains button center:")
	
	var containing_nodes = find_nodes_containing_point(ui, button_center, mute_button)
	for node_info in containing_nodes:
		print("    - %s (z:%d, filter:%s, mode:%s)" % [
			node_info.path,
			node_info.z_index,
			get_mouse_filter_name(node_info.mouse_filter),
			get_process_mode_name(node_info.process_mode)
		])
	
	print("")

func find_nodes_containing_point(root_node: Node, point: Vector2, exclude: Node) -> Array:
	var result = []
	_find_nodes_recursive(root_node, point, exclude, result)
	return result

func _find_nodes_recursive(node: Node, point: Vector2, exclude: Node, result: Array):
	if node == exclude:
		return
	
	if node is Control:
		var rect = node.get_global_rect()
		if rect.has_point(point):
			result.append({
				"node": node,
				"path": node.get_path(),
				"z_index": node.z_index,
				"mouse_filter": node.mouse_filter,
				"process_mode": node.process_mode
			})
	
	for child in node.get_children():
		_find_nodes_recursive(child, point, exclude, result)

func test_pause_button_clicks(is_paused: bool):
	var mode_label = "PAUSED" if is_paused else "UNPAUSED"
	print("TEST: Pause Button 3x3 Grid (%s)" % mode_label)
	print("─────────────────────────────────────────")
	
	var ui = ui_manager.get_node("UI")
	var pause_button = ui.get_node_or_null("%PauseButton")
	
	if not pause_button:
		test_results.append({"name": "Pause clicks (%s)" % mode_label, "passed": false, "reason": "Button not found"})
		print("  ❌ Button not found")
		return
	
	var button_rect = pause_button.get_global_rect()
	var test_points = get_3x3_grid(button_rect)
	
	var passed = 0
	var failed = 0
	var failed_labels = []
	
	for point_info in test_points:
		var point = point_info.position
		var label = point_info.label
		
		var before_count = click_counts["pause"]
		send_click_event(point)
		var after_count = click_counts["pause"]
		
		var clicked = after_count > before_count
		
		if clicked:
			passed += 1
			print("  ✅ %s (%.0f, %.0f)" % [label, point.x, point.y])
		else:
			failed += 1
			failed_labels.append(label)
			print("  ❌ %s (%.0f, %.0f) NO RESPONSE" % [label, point.x, point.y])
	
	var all_passed = failed == 0
	if all_passed:
		test_results.append({"name": "Pause clicks (%s)" % mode_label, "passed": true, "reason": ""})
		print("  ✅ PASS: %d/9 points clicked" % passed)
	else:
		test_results.append({"name": "Pause clicks (%s)" % mode_label, "passed": false, "reason": "Dead at: %s" % ", ".join(failed_labels)})
		print("  ❌ FAIL: %d/9 dead zones" % failed)
	
	print("")

func test_mute_button_clicks(is_paused: bool):
	var mode_label = "PAUSED" if is_paused else "UNPAUSED"
	print("TEST: Mute Button 3x3 Grid (%s)" % mode_label)
	print("─────────────────────────────────────────")
	
	var ui = ui_manager.get_node("UI")
	var mute_button = ui.get_node_or_null("%MuteButton")
	
	if not mute_button:
		test_results.append({"name": "Mute clicks (%s)" % mode_label, "passed": false, "reason": "Button not found"})
		print("  ❌ Button not found")
		return
	
	var button_rect = mute_button.get_global_rect()
	var test_points = get_3x3_grid(button_rect)
	
	var passed = 0
	var failed = 0
	var failed_labels = []
	
	for point_info in test_points:
		var point = point_info.position
		var label = point_info.label
		
		var before_count = click_counts["mute"]
		send_click_event(point)
		var after_count = click_counts["mute"]
		
		var clicked = after_count > before_count
		
		if clicked:
			passed += 1
			print("  ✅ %s (%.0f, %.0f)" % [label, point.x, point.y])
		else:
			failed += 1
			failed_labels.append(label)
			print("  ❌ %s (%.0f, %.0f) NO RESPONSE" % [label, point.x, point.y])
	
	var all_passed = failed == 0
	if all_passed:
		test_results.append({"name": "Mute clicks (%s)" % mode_label, "passed": true, "reason": ""})
		print("  ✅ PASS: %d/9 points clicked" % passed)
	else:
		test_results.append({"name": "Mute clicks (%s)" % mode_label, "passed": false, "reason": "Dead at: %s" % ", ".join(failed_labels)})
		print("  ❌ FAIL: %d/9 dead zones" % failed)
	
	print("")

func send_click_event(position: Vector2):
	# Send press event
	var event_press = InputEventMouseButton.new()
	event_press.button_index = MOUSE_BUTTON_LEFT
	event_press.pressed = true
	event_press.position = position
	viewport.push_input(event_press)
	
	# Send release event
	var event_release = InputEventMouseButton.new()
	event_release.button_index = MOUSE_BUTTON_LEFT
	event_release.pressed = false
	event_release.position = position
	viewport.push_input(event_release)

func get_3x3_grid(rect: Rect2) -> Array:
	var points = []
	var labels = [
		["TL", "TC", "TR"],
		["ML", "CENTER", "MR"],
		["BL", "BC", "BR"]
	]
	
	for row in range(3):
		for col in range(3):
			var x_factor = col * 0.5  # 0, 0.5, 1
			var y_factor = row * 0.5  # 0, 0.5, 1
			points.append({
				"label": labels[row][col],
				"position": rect.position + Vector2(rect.size.x * x_factor, rect.size.y * y_factor)
			})
	
	return points

func _on_pause_clicked():
	click_counts["pause"] += 1

func _on_mute_clicked():
	click_counts["mute"] += 1

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

func get_process_mode_name(mode: int) -> String:
	match mode:
		Node.PROCESS_MODE_INHERIT:
			return "INHERIT"
		Node.PROCESS_MODE_PAUSABLE:
			return "PAUSABLE"
		Node.PROCESS_MODE_WHEN_PAUSED:
			return "WHEN_PAUSED"
		Node.PROCESS_MODE_ALWAYS:
			return "ALWAYS"
		Node.PROCESS_MODE_DISABLED:
			return "DISABLED"
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
	print("BUTTON CLICK TEST SUMMARY:")
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
