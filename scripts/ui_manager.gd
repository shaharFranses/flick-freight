extends CanvasLayer

@onready var score_label = $UI/TopBar/ScoreLabel
@onready var loads_label = $UI/TopBar/LoadsLabel
@onready var timer_label = $UI/TopBar/TimerLabel
@onready var streak_label = $UI/TopBar/StreakLabel
@onready var pause_button = $UI/TopBar/Controls/PauseButton
@onready var mute_button = $UI/TopBar/Controls/MuteButton
@onready var game_over_panel = $UI/GameOverPanel
@onready var result_label = $UI/GameOverPanel/ResultLabel
@onready var final_score_label = $UI/GameOverPanel/FinalScoreLabel
@onready var retry_button = $UI/GameOverPanel/RetryButton
@onready var debug_button = $UI/DebugButton
@onready var debug_label = $UI/DebugLabel

var game_manager: Node
var visibility_callback  # Untyped - JavaScriptBridge.create_callback returns JavaScriptObject

func _ready():
	# Set process mode to always for pause UI
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	game_manager = get_node("/root/Main/GameManager")
	
	# Hide debug UI in shipping/release builds
	if !game_manager.DEBUG_MODE or !OS.is_debug_build():
		if debug_button:
			debug_button.hide()
		if debug_label:
			debug_label.hide()
	
	# Connect signals
	game_manager.score_changed.connect(_on_score_changed)
	game_manager.loads_changed.connect(_on_loads_changed)
	game_manager.timer_changed.connect(_on_timer_changed)
	game_manager.streak_changed.connect(_on_streak_changed)
	game_manager.game_won.connect(_on_game_won)
	game_manager.game_lost.connect(_on_game_lost)
	
	# Connect buttons
	pause_button.pressed.connect(_on_pause_pressed)
	mute_button.pressed.connect(_on_mute_pressed)
	retry_button.pressed.connect(_on_retry_pressed)
	debug_button.pressed.connect(_on_debug_pressed)
	
	# Initial UI
	game_over_panel.hide()
	_on_score_changed(0)
	_on_loads_changed(0, game_manager.WIN_QUOTA)
	_on_timer_changed(game_manager.ROUND_TIME)
	_on_streak_changed(0)
	
	# Hook visibility change for pause+mute (web platform) - CALLBACK not polling
	if OS.has_feature("web"):
		# DEFER callback registration to after first frame to avoid boot freeze
		# (if page loads with tab hidden, immediate visibilitychange would pause before start)
		await get_tree().process_frame
		
		# Create JavaScriptBridge callback (Godot 4.3 pattern)
		visibility_callback = JavaScriptBridge.create_callback(_on_visibility_callback)
		
		# Register callback with document.visibilitychange event
		var js_setup = """
		(function(callback) {
			window._godot_vis_cb = callback;
			document.addEventListener('visibilitychange', function() {
				if (window._godot_vis_cb) {
					window._godot_vis_cb.call(null, [document.hidden]);
				}
			});
			console.log('Godot visibility callback registered (non-polling)');
		})
		"""
		# FIXED: Pass callback as argument, not as 'this' context
		JavaScriptBridge.eval(js_setup, true).call(null, visibility_callback)
		print("🔍 Visibility: JavaScriptBridge callback registered")
	else:
		# Fallback for desktop
		get_tree().root.focus_exited.connect(_on_visibility_lost)

func _on_visibility_callback(args):
	# Called from JS via JavaScriptBridge - args[0] is document.hidden boolean
	var is_hidden = args[0] if args.size() > 0 else false
	
	if is_hidden:
		_on_visibility_lost()
		print("📴 Callback: Tab hidden")
	else:
		print("📱 Callback: Tab visible (stay paused)")

func _on_visibility_lost():
	# Auto-pause with TRIPLE GUARD
	print("🔇 TAB HIDDEN: Pausing SceneTree + muting audio")
	
	# GUARD 1: Pause scene tree
	get_tree().paused = true
	
	# GUARD 2: Time scale (belt & suspenders)
	Engine.time_scale = 0.0
	
	# GUARD 3: Game manager flags
	if !game_manager.is_game_over:
		game_manager.is_paused = true
		if game_manager.has("tab_hidden_paused"):
			game_manager.set("tab_hidden_paused", true)
		pause_button.text = "Resume"
	
	# Mute audio
	AudioServer.set_bus_mute(0, true)
	mute_button.text = "Unmute"


func _on_score_changed(new_score: int):
	score_label.text = "Score: %d" % new_score

func _on_loads_changed(loads: int, quota: int):
	loads_label.text = "Loads: %d/%d" % [loads, quota]
	# On-screen flash on successful load
	show_load_flash()

func show_load_flash():
	# Create a flash overlay
	var flash = ColorRect.new()
	flash.color = Color(0.2, 1.0, 0.2, 0.3)  # Green flash
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(flash)
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)

func _on_timer_changed(time: float):
	var seconds = int(ceil(time))
	timer_label.text = "Time: %d" % seconds

func _on_streak_changed(streak: int):
	if streak > 0:
		streak_label.text = "Streak: +%d" % streak
		streak_label.show()
	else:
		streak_label.hide()

func _on_pause_pressed():
	# Resume also clears tab_hidden_paused
	if game_manager.is_paused:
		# Resuming
		get_tree().paused = false
		Engine.time_scale = 1.0
		game_manager.is_paused = false
		if game_manager.has("tab_hidden_paused"):
			game_manager.set("tab_hidden_paused", false)
	else:
		# Pausing
		get_tree().paused = true
		game_manager.is_paused = true
	
	pause_button.text = "Resume" if game_manager.is_paused else "Pause"

func _on_mute_pressed():
	# Stub for audio mute
	var is_muted = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, !is_muted)
	mute_button.text = "Unmute" if !is_muted else "Mute"

func _on_game_won():
	show_game_over("YOU WIN!", game_manager.current_score)

func _on_game_lost():
	show_game_over("TIME'S UP!", game_manager.current_score)

func show_game_over(result: String, final_score: int):
	result_label.text = result
	final_score_label.text = "Final Score: %d" % final_score
	game_over_panel.show()
	
	# Midroll ad stub - would trigger here
	print("MIDROLL AD SLOT: Attempt ended")

func _on_retry_pressed():
	game_manager.restart_game()

func _on_debug_pressed():
	game_manager.debug_add_credit()

func update_debug_label(text: String):
	if debug_label:
		debug_label.text = text
