extends CanvasLayer

@onready var score_label = $UI/TopBar/ScoreLabel
@onready var loads_label = $UI/TopBar/LoadsLabel
@onready var timer_label = $UI/TopBar/TimerLabel
@onready var streak_label = $UI/TopBar/StreakLabel
@onready var pause_button = $UI/PauseButton
@onready var mute_button = $UI/MuteButton
@onready var game_over_panel = $UI/GameOverPanel
@onready var result_label = $UI/GameOverPanel/ResultLabel
@onready var final_score_label = $UI/GameOverPanel/FinalScoreLabel
@onready var retry_button = $UI/GameOverPanel/RetryButton
@onready var debug_button = $UI/DebugButton

var game_manager: Node

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
	
	# Hook visibility change for pause+mute
	get_tree().root.focus_exited.connect(_on_visibility_lost)

func _on_visibility_lost():
	# Stub: pause and mute on visibility loss
	if !game_manager.is_game_over and !game_manager.is_paused:
		_on_pause_pressed()
	print("VISIBILITY LOST: Auto-pause+mute stub")

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
	# Always show streak label
	streak_label.text = "Streak: +%d" % streak
	streak_label.show()

func _on_pause_pressed():
	game_manager.toggle_pause()
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
	
	# Re-enable retry button (may have been disabled from previous retry)
	retry_button.disabled = false
	
	# Midroll ad stub - would trigger here
	print("MIDROLL AD SLOT: Attempt ended")

func _on_retry_pressed():
	# Disable button to prevent double-clicks during async restart
	retry_button.disabled = true
	
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
