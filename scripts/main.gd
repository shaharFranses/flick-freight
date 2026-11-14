extends Node
## Boot + flow: opens on the main menu (over the next unbeaten level), switches
## levels, pauses, and owns the shared UI theme.

var game: Game = null
var hud: Hud = null
var screens: Screens
var sfx: Sfx
var level_index := 0
var in_menu := false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	sfx = Sfx.new()
	add_child(sfx)
	screens = Screens.new()
	add_child(screens)
	screens.resume.connect(_resume)
	screens.restart.connect(func():
		_track_leave("level_restart")
		start_level(level_index))
	screens.next_level.connect(func(): start_level(Levels.next_of(level_index)))
	screens.open_levels.connect(func(): screens.show_levels(in_menu or (game != null and not game.ended)))
	screens.play_level.connect(start_level)
	screens.close_levels.connect(func():
		if in_menu:
			screens.show_menu(level_index)
		elif game and game.ended:
			screens.close()
		else:
			_show_pause())
	screens.play.connect(func(): start_level(SaveData.first_unbeaten()))
	screens.open_menu.connect(show_menu)
	var q = _query()
	Analytics.track("session_start", {"stars": SaveData.total_stars(), "next_level": Levels.number_of(SaveData.first_unbeaten()),
		"new_player": not SaveData.get_flag("tutorial_done", false)})
	# ?unlock=1 / --unlock=1: every level is open for play-testing (same gate as the level
	# jump). Nothing is written to the save.
	Levels.dev_unlock = q.get("unlock", "0") == "1" and _dev_jump_allowed()
	# ?fresh=1 / --fresh=1: start as a new player (tutorial included) without touching the save
	if q.get("fresh", "0") == "1" and _dev_jump_allowed():
		SaveData.fresh = true
		SaveData._cfg = null
	if q.has("level") and _dev_jump_allowed():
		start_level(Levels.id_of_number(int(q.level)))  # the number players see; skips the menu
	else:
		show_menu()


## Main menu: the next unbeaten level is built (not started) as a live backdrop.
func show_menu():
	if game and not game.ended and not in_menu:
		Portal.gameplay_stop()
		_track_leave("level_quit")
	in_menu = true
	get_tree().paused = false
	level_index = SaveData.first_unbeaten()
	_clear_level()
	game = Game.new()
	game.setup(level_index)
	add_child(game)
	move_child(game, 0)
	for t in game.slots.size():
		game._new_truck(t)  # trucks drive in and park; no cargo is spawned until PLAY
	Sfx.start_music(Levels.world_of(level_index).get("music", Sfx.MUSIC))
	screens.show_menu(level_index)


func _clear_level():
	if game:
		game.queue_free()
		game = null
	if hud:
		hud.queue_free()
		hud = null


## Level-jump (?level=N / --level=N) is a dev tool: allowed in debug builds,
## on localhost and on the GitHub Pages play-test site, never on portals.
func _dev_jump_allowed() -> bool:
	if OS.is_debug_build():
		return true
	if OS.has_feature("web"):
		var host = JavaScriptBridge.eval("location.hostname || ''")
		if host is String:
			return host == "localhost" or host == "127.0.0.1" or host.ends_with(".github.io")
	return false


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
	in_menu = false
	screens.close()
	get_tree().paused = false
	_clear_level()
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
	Portal.gameplay_start()
	var props = Analytics.level_props(level_index)
	props["best_stars"] = SaveData.stars(level_index)
	Analytics.track("level_start", props)


## `auto`: paused because the tab lost focus. CrazyGames handles that itself, so it's no game break.
func _show_pause(auto := false):
	if in_menu or game == null or game.ended:
		return
	get_tree().paused = true
	screens.show_pause()
	if not auto:
		Portal.gameplay_stop()


func _resume():
	screens.close()
	get_tree().paused = false
	Portal.gameplay_start()


## Left a level before it ended (restart or back to the menu): how far the player got.
func _track_leave(event: String):
	if game == null or game.ended or in_menu:
		return
	var props = Analytics.level_props(level_index)
	props["thrown"] = game.thrown
	props["loaded"] = game.delivered
	props["seconds"] = snappedf(game.frame / 60.0, 0.1)
	Analytics.track(event, props)


func _on_finished(stars: int, delivered: int, total: int):
	Portal.gameplay_stop()
	var props = Analytics.level_props(level_index)
	props["stars"] = stars
	props["loaded"] = delivered
	props["total"] = total
	props["thrown"] = game.thrown
	props["seconds"] = snappedf(game.frame / 60.0, 0.1)
	if stars == 0:
		props["reason"] = "time" if game.timed_out else ("missing_type" if not game.missing_kinds().is_empty() else "too_few")
	Analytics.track("level_end", props)
	var next = Levels.next_of(level_index)
	if stars > 0 and (next < 0 or Levels.get_level(next).world != Levels.get_level(level_index).world):
		Portal.happytime()  # the world's last level
	screens.show_results(level_index, stars, delivered, total)


func _notification(what: int):
	# auto-pause when the tab/window loses focus (portal best practice)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if game and not in_menu and not game.ended and not screens.is_open():
			_show_pause(true)


func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if in_menu:
			return
		if event.keycode == KEY_P:
			if screens.is_open() and get_tree().paused:
				_resume()
			else:
				_show_pause()
		elif event.keycode == KEY_R and game:
			start_level(level_index)
