extends Node
## Boot + flow: lands straight in gameplay (next unbeaten level), switches
## levels, pauses, and owns the shared UI theme.

var game: Game = null
var hud: Hud = null
var screens: Screens
var sfx: Sfx
var level_index := 0


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	sfx = Sfx.new()
	add_child(sfx)
	screens = Screens.new()
	add_child(screens)
	screens.resume.connect(_resume)
	screens.restart.connect(func(): start_level(level_index))
	screens.next_level.connect(func(): start_level(level_index + 1))
	screens.open_levels.connect(func(): screens.show_levels(game != null and not game.ended))
	screens.play_level.connect(start_level)
	screens.close_levels.connect(func():
		if game and game.ended:
			screens.close()
		else:
			_show_pause())
	var q = _query()
	Game.glue_loads = SaveData.get_flag("glue_loads", true)
	if q.has("glue"):
		set_glue(q.glue != "0")
	screens.toggle_glue.connect(func():
		set_glue(not Game.glue_loads)
		start_level(level_index))
	var start = SaveData.first_unbeaten()
	if q.has("level"):
		start = clampi(int(q.level) - 1, 0, Levels.count() - 1)
	start_level(start)


## Glued (default) or unglued cargo; remembered between sessions.
func set_glue(on: bool):
	Game.glue_loads = on
	SaveData.set_flag("glue_loads", on)


func _query() -> Dictionary:
	var out = {}
	if OS.has_feature("web"):
		var s = JavaScriptBridge.eval("location.search || ''")
		if s is String:
			for kv in s.trim_prefix("?").split("&", false):
				var p = kv.split("=")
				if p.size() == 2:
					out[p[0]] = p[1]
	for a in OS.get_cmdline_user_args():
		var p = a.trim_prefix("--").split("=")
		if p.size() == 2:
			out[p[0]] = p[1]
	return out


func start_level(i: int):
	level_index = clampi(i, 0, Levels.count() - 1)
	screens.close()
	get_tree().paused = false
	if game:
		game.queue_free()
	if hud:
		hud.queue_free()
	game = Game.new()
	game.setup(level_index)
	add_child(game)
	move_child(game, 0)
	hud = Hud.new()
	add_child(hud)
	hud.bind(game)
	hud.pause_pressed.connect(_show_pause)
	game.finished.connect(_on_finished)
	game.start()
	Sfx.start_music(Levels.world_of(level_index).get("music", Sfx.MUSIC))


func _show_pause():
	if game == null or game.ended:
		return
	get_tree().paused = true
	screens.show_pause()


func _resume():
	screens.close()
	get_tree().paused = false


func _on_finished(stars: int, delivered: int, total: int):
	screens.show_results(level_index, stars, delivered, total)


func _notification(what: int):
	# auto-pause when the tab/window loses focus (portal best practice)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if game and not game.ended and not screens.is_open():
			_show_pause()


func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			if screens.is_open() and get_tree().paused:
				_resume()
			else:
				_show_pause()
		elif event.keycode == KEY_R and game:
			start_level(level_index)
