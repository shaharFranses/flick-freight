extends CanvasLayer

@onready var score_label = $UI/ScorePlate/ScoreLabel
@onready var loads_label = $UI/LoadsLabel
@onready var timer_label = $UI/TimerLabel
@onready var streak_label = $UI/StreakPlate/StreakLabel
@onready var pause_button = %PauseButton
@onready var mute_button = %MuteButton
@onready var mute_slash = %MuteSlash
@onready var qa_badge = %QABadge
@onready var game_over_panel = $UI/GameOverPanel
@onready var result_label = $UI/GameOverPanel/ResultLabel
@onready var final_score_label = $UI/GameOverPanel/FinalScoreLabel
@onready var best_score_label = %BestScoreLabel
@onready var retry_button = $UI/GameOverPanel/RetryButton
@onready var debug_button = $UI/DebugButton

var game_manager: Node
var paused_overlay: ColorRect = null
var paused_label: Label = null
var has_booted: bool = false
var was_paused_before_hide: bool = false
var last_loads_count: int = 0  # B: Track loads to only flash on increase
var hint_label: Label = null  # (7): One-line hint label
var hint_timer: Timer = null  # QA ITEM 4: 8-second hint fade timer
var hint_timer_started: bool = false  # QA ITEM 4: Track if timer started this page load
var best_score: int = 0  # Game-over: Persisted best score
var splash_panel: ColorRect = null  # Boot splash/title screen

func _ready():
	# Set process mode to always for pause UI
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	game_manager = get_node("/root/Main/GameManager")
	
	# Connect signals
	game_manager.score_changed.connect(_on_score_changed)
	game_manager.loads_changed.connect(_on_loads_changed)
	game_manager.timer_changed.connect(_on_timer_changed)
	game_manager.streak_changed.connect(_on_streak_changed)
	game_manager.game_won.connect(_on_game_won)
	game_manager.game_lost.connect(_on_game_lost)
	game_manager.time_delta.connect(_on_time_delta)
	game_manager.ticket_changed.connect(_on_ticket_changed)
	_create_timer_bar()
	_create_ticket_panel()
	_on_ticket_changed(game_manager.ticket)
	
	# Connect buttons
	pause_button.pressed.connect(_on_pause_pressed)
	mute_button.pressed.connect(_on_mute_pressed)
	retry_button.pressed.connect(_on_retry_pressed)
	debug_button.pressed.connect(_on_debug_pressed)
	
	# Initial UI
	game_over_panel.hide()
	_on_score_changed(0)
	_on_loads_changed(0, 0)
	_on_timer_changed(game_manager.ROUND_TIME)
	_on_streak_changed(0)
	
	# ITEM (c): Show QA badge if in QA mode
	if game_manager.qa_mode:
		qa_badge.visible = true
	
	# LOW (b) FIX: Create PAUSED overlay (hidden by default)
	_create_paused_overlay()
	
	# A: Hook visibility change AFTER boot (deferred to avoid auto-pause on load)
	call_deferred("_hook_visibility_change")
	
	# (1): Scale buttons to maintain >= 48 CSS px minimum
	call_deferred("_setup_button_scaling")
	
	# QA ITEM 3: Style Retry button with contrasting fill
	_style_retry_button()
	
	# (7): Show one-line hint at start
	_create_hint_label()
	
	# Game-over: Load best score from persistent storage
	_load_best_score()
	
	# Boot splash: Show title screen (timer held until dismissed)
	_create_splash_screen()

func _hook_visibility_change():
	"""A: Defer visibility hook until after boot to prevent auto-pause on load"""
	await get_tree().process_frame
	has_booted = true
	
	if OS.has_feature("web"):
		# QA ITEM 7b: Primary visibilitychange + blur/pagehide fallbacks
		var js_code = """
		document.addEventListener('visibilitychange', function() {
			if (typeof godot !== 'undefined' && godot.UIManager) {
				godot.UIManager._on_visibility_changed(document.hidden);
			}
		});
		
		// QA ITEM 7b: Fallback for blur (window loses focus)
		window.addEventListener('blur', function() {
			if (typeof godot !== 'undefined' && godot.UIManager) {
				// Poll document.hidden after boot, don't trust blur alone
				godot.UIManager._on_visibility_changed(document.hidden);
			}
		});
		
		// QA ITEM 7b: Fallback for pagehide (tab/window closing)
		window.addEventListener('pagehide', function() {
			if (typeof godot !== 'undefined' && godot.UIManager) {
				godot.UIManager._on_visibility_changed(true);
			}
		});
		"""
		JavaScriptBridge.eval(js_code)
		
		# Register callback in global scope
		JavaScriptBridge.get_interface("godot").UIManager = JavaScriptBridge.create_object("Object")
		JavaScriptBridge.get_interface("godot").UIManager._on_visibility_changed = _on_visibility_changed

func _on_visibility_changed(is_hidden: bool):
	"""A: Auto-pause when hidden, restore state when visible"""
	if !has_booted or game_manager.is_game_over:
		return
	
	if is_hidden:
		# Store pre-hide state
		was_paused_before_hide = game_manager.is_paused
		if !was_paused_before_hide:
			_on_pause_pressed()
			print("VISIBILITY LOST: Auto-paused")
	else:
		# Restore pre-hide state
		if !was_paused_before_hide and game_manager.is_paused:
			_on_pause_pressed()
			print("VISIBILITY RESTORED: Auto-resumed")

func _on_score_changed(new_score: int):
	score_label.text = "Score: %d" % new_score

func _on_loads_changed(loads: int, quota: int):
	loads_label.text = "Loads: %d" % loads  # r5: no quota in the timer run
	last_loads_count = loads
	# QA ITEM 1: Removed full-screen green flash - localized flash is in game_manager.spawn_hit_juice()

func _on_timer_changed(time: float):
	timer_label.text = "Time: %.1f" % time
	_update_timer_bar(time)

func _on_streak_changed(streak: int):
	# Always show streak label
	streak_label.text = "Streak: +%d" % streak
	streak_label.show()

func _on_pause_pressed():
	game_manager.toggle_pause()
	# ITEM 4 FIX: Pause icon looks identical before/after resume (no text change)
	# LOW (b) FIX: Show/hide PAUSED overlay
	_update_paused_overlay()

func _on_mute_pressed():
	# Toggle audio mute
	var is_muted = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, !is_muted)
	# ITEM 4 FIX: Show/hide slash on speaker icon
	mute_slash.visible = !is_muted

func _on_game_won():
	show_game_over("YOU WIN!", game_manager.current_score)

func _on_game_lost():
	show_game_over("TIME'S UP!", game_manager.current_score)

func show_game_over(result: String, final_score: int):
	result_label.text = result
	final_score_label.text = "Score: %d" % final_score
	
	# Game-over: Update best score if this is a new record
	if final_score > best_score:
		best_score = final_score
		_save_best_score()
	
	best_score_label.text = "BEST: %d" % best_score
	_apply_hud_scale()
	game_over_panel.show()
	game_over_panel.z_index = 100  # Above everything
	
	# QA ITEM 5: Hide hint on game over
	if hint_label:
		hint_label.visible = false
	
	# Re-enable retry button (may have been disabled from previous retry)
	retry_button.disabled = false
	
	# Midroll ad stub - would trigger here
	print("MIDROLL AD SLOT: Attempt ended")

func _on_retry_pressed():
	# Disable button to prevent double-clicks during async restart
	retry_button.disabled = true
	
	# A: Clear visibility pause state on retry
	was_paused_before_hide = false
	
	# Free any in-flight packages immediately
	var packages = get_tree().get_nodes_in_group("packages")
	for pkg in packages:
		if is_instance_valid(pkg):
			pkg.queue_free()
	
	# Hide game over panel
	game_over_panel.hide()
	
	# Restart game (async)
	game_manager.restart_game()

func _on_debug_pressed():
	game_manager.debug_add_credit()

func _create_paused_overlay():
	"""LOW (b): Create dim overlay with PAUSED label"""
	# Create dim overlay
	paused_overlay = ColorRect.new()
	paused_overlay.name = "PausedOverlay"
	paused_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	paused_overlay.color = Color(0, 0, 0, 0.6)  # Dim black overlay
	paused_overlay.visible = false
	paused_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block Resume button
	paused_overlay.z_index = -2  # Below HUD elements so buttons stay bright
	$UI.add_child(paused_overlay)
	
	# Create PAUSED label
	paused_label = Label.new()
	paused_label.name = "PausedLabel"
	paused_label.text = "PAUSED"
	paused_label.add_theme_font_size_override("font_size", 48)
	paused_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	paused_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paused_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	paused_label.set_anchors_preset(Control.PRESET_CENTER)
	paused_label.position = Vector2(-150, -100)  # Center it
	paused_label.size = Vector2(300, 100)
	paused_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paused_overlay.add_child(paused_label)

func _update_paused_overlay():
	"""Show/hide PAUSED overlay based on pause state"""
	if paused_overlay:
		paused_overlay.visible = game_manager.is_paused

func _create_hint_label():
	"""(7): Create one-line hint that fades after first flick"""
	hint_label = Label.new()
	hint_label.text = "Flick the package into the truck"
	hint_label.add_theme_font_size_override("font_size", 22)
	hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.set_anchors_preset(Control.PRESET_CENTER)
	hint_label.position = Vector2(-200, 100)  # Below center
	hint_label.size = Vector2(400, 40)
	hint_label.z_index = -5  # QA ITEM 5: Below PAUSED dim (-2) and modals
	$UI.add_child(hint_label)
	
	# QA ITEM 4: Create 8-second timer (starts when round timer starts)
	hint_timer = Timer.new()
	hint_timer.wait_time = 8.0
	hint_timer.one_shot = true
	hint_timer.timeout.connect(_on_hint_timer_timeout)
	add_child(hint_timer)
	
	# Connect to package flicked signal to fade hint on first hit
	game_manager.connect("score_changed", _on_hint_fade)
	
	# Connect to timer_changed to start hint timer when round starts
	game_manager.connect("timer_changed", _on_hint_check_timer_start)

func _on_hint_check_timer_start(time_left: float):
	"""QA ITEM 4: Start hint timer when round timer starts (once per page load)"""
	if not hint_timer_started and hint_timer and time_left < game_manager.ROUND_TIME:
		hint_timer_started = true
		hint_timer.start()
		# Disconnect after starting once
		if game_manager.is_connected("timer_changed", _on_hint_check_timer_start):
			game_manager.disconnect("timer_changed", _on_hint_check_timer_start)

func _on_hint_timer_timeout():
	"""QA ITEM 4: Fade hint after 8 seconds"""
	_on_hint_fade(0)

func _on_hint_fade(_score: int):
	"""QA ITEM 7a: Fade hint after first score or 8s timer, never reappear"""
	if hint_label and hint_label.visible:
		# Stop timer if running
		if hint_timer and not hint_timer.is_stopped():
			hint_timer.stop()
		
		var tween = create_tween()
		tween.tween_property(hint_label, "modulate:a", 0.0, 1.0)
		tween.tween_callback(func(): 
			hint_label.visible = false
			# Disconnect so hint never reappears after Retry
			if game_manager.is_connected("score_changed", _on_hint_fade):
				game_manager.disconnect("score_changed", _on_hint_fade)
			if game_manager.is_connected("timer_changed", _on_hint_check_timer_start):
				game_manager.disconnect("timer_changed", _on_hint_check_timer_start)
		)

func _load_best_score():
	"""Game-over: Load best score from persistent storage with failure guard"""
	if OS.has_feature("web"):
		# Web: Try localStorage via JavaScriptBridge
		var js_code = "localStorage.getItem('flick_freight_best_score') || '0'"
		var stored = JavaScriptBridge.eval(js_code)
		if stored and stored is String:
			best_score = int(stored)
	else:
		# Desktop: Use ConfigFile
		var config = ConfigFile.new()
		var err = config.load("user://flick_freight.cfg")
		if err == OK:
			best_score = config.get_value("game", "best_score", 0)

func _save_best_score():
	"""Game-over: Save best score to persistent storage with failure guard"""
	if OS.has_feature("web"):
		# Web: Save to localStorage via JavaScriptBridge
		var js_code = "localStorage.setItem('flick_freight_best_score', '%d')" % best_score
		JavaScriptBridge.eval(js_code)
	else:
		# Desktop: Use ConfigFile
		var config = ConfigFile.new()
		config.set_value("game", "best_score", best_score)
		config.save("user://flick_freight.cfg")

func _create_splash_screen():
	"""Boot splash: Title screen with tap-to-start (timer held until dismissed)"""
	# Skip splash in headless mode (for tests)
	if DisplayServer.get_name() == "headless":
		return
	
	splash_panel = ColorRect.new()
	splash_panel.name = "SplashScreen"
	splash_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash_panel.color = Color(0.08, 0.08, 0.12, 0.98)
	splash_panel.z_index = 150
	$UI.add_child(splash_panel)
	
	# Title
	var title = Label.new()
	title.text = "Flick Freight"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-200, -300)
	title.size = Vector2(400, 80)
	splash_panel.add_child(title)
	
	# Instructions
	var instructions = Label.new()
	instructions.text = "Flick the package into the truck"
	instructions.add_theme_font_size_override("font_size", 24)
	instructions.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instructions.set_anchors_preset(Control.PRESET_CENTER)
	instructions.position = Vector2(-250, -200)
	instructions.size = Vector2(500, 40)
	splash_panel.add_child(instructions)
	
	# Tap to start
	var tap_hint = Label.new()
	tap_hint.text = "Tap or Click to Start"
	tap_hint.add_theme_font_size_override("font_size", 28)
	tap_hint.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	tap_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tap_hint.set_anchors_preset(Control.PRESET_CENTER)
	tap_hint.position = Vector2(-200, 100)
	tap_hint.size = Vector2(400, 50)
	splash_panel.add_child(tap_hint)
	
	# Dismiss splash on click/tap
	splash_panel.gui_input.connect(_on_splash_input)
	
	# Pause game until splash dismissed
	if not game_manager.is_paused:
		game_manager.toggle_pause()

func _on_splash_input(event: InputEvent):
	"""Boot splash: Dismiss on click/tap and start game"""
	if event is InputEventMouseButton and event.pressed:
		if splash_panel:
			splash_panel.queue_free()
			splash_panel = null
			# Unpause to start game
			if game_manager.is_paused:
				game_manager.toggle_pause()

func _style_retry_button():
	"""QA ITEM 3: Apply StyleBoxFlat with bright blue fill to Retry button"""
	var retry_btn = $UI/GameOverPanel/RetryButton
	if not retry_btn:
		return
	
	# Create StyleBoxFlat for normal state - bright blue with light border
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.5, 0.9, 1.0)  # Bright blue
	style_normal.border_color = Color(0.7, 0.85, 1.0, 1.0)  # Light blue border
	style_normal.border_width_left = 3
	style_normal.border_width_top = 3
	style_normal.border_width_right = 3
	style_normal.border_width_bottom = 3
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8
	
	# Hover state - lighter blue
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.3, 0.6, 1.0, 1.0)
	style_hover.border_color = Color(0.8, 0.9, 1.0, 1.0)
	style_hover.border_width_left = 3
	style_hover.border_width_top = 3
	style_hover.border_width_right = 3
	style_hover.border_width_bottom = 3
	style_hover.corner_radius_top_left = 8
	style_hover.corner_radius_top_right = 8
	style_hover.corner_radius_bottom_left = 8
	style_hover.corner_radius_bottom_right = 8
	
	# Pressed state - darker blue
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.15, 0.4, 0.75, 1.0)
	style_pressed.border_color = Color(0.6, 0.75, 0.9, 1.0)
	style_pressed.border_width_left = 3
	style_pressed.border_width_top = 3
	style_pressed.border_width_right = 3
	style_pressed.border_width_bottom = 3
	style_pressed.corner_radius_top_left = 8
	style_pressed.corner_radius_top_right = 8
	style_pressed.corner_radius_bottom_left = 8
	style_pressed.corner_radius_bottom_right = 8
	
	# Apply styles to button
	retry_btn.add_theme_stylebox_override("normal", style_normal)
	retry_btn.add_theme_stylebox_override("hover", style_hover)
	retry_btn.add_theme_stylebox_override("pressed", style_pressed)
	retry_btn.add_theme_stylebox_override("focus", style_normal)
	retry_btn.add_theme_stylebox_override("disabled", style_normal)
	
	# White bold text
	retry_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	retry_btn.add_theme_font_size_override("font_size", 32)

func _setup_button_scaling():
	"""r3: Screen-pixel floor for Pause/Mute (>=48 CSS px) and Retry (>=64 CSS px).
	Root cause of r2h miss: in canvas_items stretch mode get_viewport().get_visible_rect()
	returns the 720x1280 DESIGN size, so the computed scale was always 1.0. Use the real
	window size (get_tree().root.size) and recompute on every resize."""
	set_process(false)
	get_tree().root.size_changed.connect(_apply_hud_scale)
	_apply_hud_scale()
	await get_tree().process_frame
	_apply_hud_scale()
	await get_tree().create_timer(0.5, true, false, true).timeout
	_apply_hud_scale()

const DESIGN_SIZE = Vector2(720, 1280)
const BTN_DESIGN = 58.0
const BTN_MIN_CSS = 50.0   # floor 48, aim 50 for rounding margin
const RETRY_MIN_CSS = 78.0 # floor 64 on the FILL (border+rounding excluded), aim 66+
var css_per_unit: float = 1.0

func _get_css_per_unit() -> float:
	if DisplayServer.get_name() == "headless":
		return 1.0
	var win = Vector2(get_tree().root.size)
	if win.x <= 0 or win.y <= 0:
		return 1.0
	var phys = min(win.x / DESIGN_SIZE.x, win.y / DESIGN_SIZE.y)  # stretch aspect keep
	var dpr = 1.0
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("window.devicePixelRatio || 1")
		if v is float or v is int:
			dpr = max(float(v), 0.1)
	return phys / dpr

func _apply_hud_scale():
	if !is_inside_tree():
		return
	css_per_unit = _get_css_per_unit()
	var s = clamp(BTN_MIN_CSS / (BTN_DESIGN * css_per_unit), 1.0, 3.0)
	var btn = BTN_DESIGN * s
	var ui = $UI
	var pause_plate = ui.get_node_or_null("PausePlate")
	var mute_plate = ui.get_node_or_null("MutePlate")
	if pause_plate:
		pause_plate.scale = Vector2(s, s)
		pause_plate.position = Vector2(20, 20)
	var mute_left = 700.0 - btn
	if mute_plate:
		mute_plate.scale = Vector2(s, s)
		mute_plate.position = Vector2(mute_left, 20)
	# Reflow right column (Time / Loads / QA badge) to stay left of Mute
	var col_right = min(640.0, mute_left - 8.0)
	var col_w = 140.0 if s > 1.0 else 160.0
	for n in ["TimerLabel", "LoadsLabel", "QABadge"]:
		var c = ui.get_node_or_null(n)
		if c:
			c.position.x = col_right - col_w
			c.size.x = col_w
	var score_plate = ui.get_node_or_null("ScorePlate")
	if score_plate:
		var right = min(470.0, col_right - col_w - 8.0)
		var left = max(20.0 + btn + 10.0, 250.0 - max(0.0, 470.0 - right))
		score_plate.position.x = left
		score_plate.size.x = right - left
	# Streak moves right of the Pause button when Pause grows past its row
	var streak_plate = ui.get_node_or_null("StreakPlate")
	if streak_plate:
		streak_plate.position = Vector2(20.0 if 20.0 + btn <= 92.0 else 20.0 + btn + 10.0, 100.0)
	var backing = ui.get_node_or_null("HUDBacking")
	if backing:
		backing.size.y = max(155.0, 20.0 + btn + 8.0)
	_apply_retry_size()

func _apply_retry_size():
	var retry_btn = $UI/GameOverPanel.get_node_or_null("RetryButton")
	var panel = $UI/GameOverPanel
	if !retry_btn:
		return
	var h = max(70.0, ceil(RETRY_MIN_CSS / css_per_unit))
	var w = max(240.0, h * 2.4)
	retry_btn.scale = Vector2.ONE
	retry_btn.offset_left = -w / 2.0
	retry_btn.offset_right = w / 2.0
	retry_btn.add_theme_font_size_override("font_size", int(clamp(32.0 * h / 70.0, 32.0, 64.0)))
	# Grow the panel downward only; children are anchored to the panel centre, which
	# moves down by d when the panel grows, so shift them up by d to keep them fixed.
	var bottom = max(180.0, 70.0 + h + 28.0)
	var d = (bottom - 180.0) * 0.5
	panel.offset_top = -180.0
	panel.offset_bottom = bottom
	retry_btn.offset_top = 70.0 - d
	retry_btn.offset_bottom = 70.0 + h - d
	var base = {"ResultLabel": [-120.0, -60.0], "FinalScoreLabel": [-40.0, 0.0], "BestScoreLabel": [10.0, 50.0]}
	for n in base:
		var c = panel.get_node_or_null(n)
		if c:
			c.offset_top = base[n][0] - d
			c.offset_bottom = base[n][1] - d
	panel.offset_left = min(-220.0, -w / 2.0 - 20.0)
	panel.offset_right = -panel.offset_left

# ---------------- r5: timer bar, fly-in, ticket ----------------
var timer_bar_bg: ColorRect = null
var timer_bar_fill: ColorRect = null
var qa_delta_label: Label = null
var ticket_panel: ColorRect = null
var ticket_label: Label = null
const BAR_POS = Vector2(176, 122)
const BAR_SIZE = Vector2(524, 26)

func _create_timer_bar():
	timer_bar_bg = ColorRect.new()
	timer_bar_bg.name = "TimerBarBg"
	timer_bar_bg.position = BAR_POS
	timer_bar_bg.size = BAR_SIZE
	timer_bar_bg.color = Color(0.05, 0.07, 0.12, 0.95)
	timer_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(timer_bar_bg)
	timer_bar_fill = ColorRect.new()
	timer_bar_fill.name = "TimerBarFill"
	timer_bar_fill.position = Vector2(3, 3)
	timer_bar_fill.size = BAR_SIZE - Vector2(6, 6)
	timer_bar_fill.color = Color(0.3, 0.85, 0.45)
	timer_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_bar_bg.add_child(timer_bar_fill)
	if game_manager.qa_mode:
		qa_delta_label = Label.new()
		qa_delta_label.name = "QADelta"
		qa_delta_label.position = Vector2(176, 150)
		qa_delta_label.size = Vector2(524, 24)
		qa_delta_label.add_theme_font_size_override("font_size", 20)
		qa_delta_label.add_theme_color_override("font_color", Color(1, 1, 0.4))
		qa_delta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$UI.add_child(qa_delta_label)

func _update_timer_bar(time: float):
	if timer_bar_fill == null:
		return
	var cap = game_manager.T.clock_cap
	var frac = clamp(time / cap, 0.0, 1.0)
	timer_bar_fill.size.x = (BAR_SIZE.x - 6) * frac
	if time < game_manager.T.low_time_warning and time > 0.0:
		# flash red ~4 Hz under 5 s (tick SFX: TODO, no audio assets yet)
		var on = int(Time.get_ticks_msec() / 125) % 2 == 0
		timer_bar_fill.color = Color(1, 0.2, 0.2) if on else Color(0.6, 0.1, 0.1)
	else:
		timer_bar_fill.color = Color(0.3, 0.85, 0.45) if frac > 0.34 else Color(1, 0.75, 0.2)
	if qa_delta_label:
		qa_delta_label.text = "QA t=%.2f  last %+.2f  lvl %d  period %.2fs  mult x%d" % [time, game_manager.last_time_delta, game_manager.level_index() + 1, game_manager.bay_period_for_level(game_manager.level_index()), game_manager.multiplier()]

func _on_time_delta(amount: float, from_pos: Vector2):
	if is_zero_approx(amount):
		return
	var l = Label.new()
	l.text = "%+.1f" % amount
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", Color(0.4, 1, 0.5) if amount > 0 else Color(1, 0.35, 0.3))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.12))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = from_pos - Vector2(40, 30)
	$UI.add_child(l)
	var target = BAR_POS + Vector2((BAR_SIZE.x - 6) * clamp(game_manager.time_remaining / game_manager.T.clock_cap, 0.0, 1.0) - 40, -6)
	var dur = 0.6 * (3.0 if game_manager.qa_mode else 1.0)
	var tw = l.create_tween()
	tw.tween_property(l, "position", target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(l, "modulate:a", 0.0, 0.15)
	tw.tween_callback(l.queue_free)

func _create_ticket_panel():
	# Rides with the truck (child of TruckBay), just below the bed.
	var bay = get_node_or_null("/root/Main/World/TruckBay")
	if bay == null:
		return
	ticket_panel = ColorRect.new()
	ticket_panel.name = "OrderTicket"
	ticket_panel.position = Vector2(-150, 86)
	ticket_panel.size = Vector2(300, 44)
	ticket_panel.color = Color(0.96, 0.93, 0.82, 0.95)
	ticket_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bay.add_child(ticket_panel)
	ticket_label = Label.new()
	ticket_label.size = ticket_panel.size
	ticket_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ticket_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ticket_label.add_theme_font_size_override("font_size", 24)
	ticket_label.add_theme_color_override("font_color", Color(0.12, 0.14, 0.22))
	ticket_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticket_panel.add_child(ticket_label)

func _on_ticket_changed(t: Array):
	if ticket_label == null:
		return
	var left = {}
	var done = 0
	for item in t:
		if item.done:
			done += 1
		else:
			left[item.type] = left.get(item.type, 0) + 1
	var parts = []
	for k in ["box", "crate", "barrel"]:
		if left.has(k):
			parts.append("%d %s" % [left[k], k.to_upper() + ("ES" if k == "box" and left[k] > 1 else ("S" if left[k] > 1 else ""))])
	ticket_label.text = "ORDER: " + ", ".join(parts) + ("  %d/%d" % [done, t.size()] if done > 0 else "")
