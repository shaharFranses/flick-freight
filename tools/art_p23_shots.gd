extends SceneTree
## Phase 2/3 shot set: the first level of every world, each world's level-select page,
## and a 2-star results card. Needs a display:
##   xvfb-run -s "-screen 0 1280x720x24" godot --fixed-fps 60 --resolution 1280x720 \
##     -s res://tools/art_p23_shots.gd -- --out=/tmp/shots
## Frame counts are fixed so two trees can be diffed pixel for pixel.

var out := "/tmp/ff-p23-shots"
var main: Node
var steps: Array = []
var wait := 0
var frame := 0


func _init():
	for a in OS.get_cmdline_user_args():
		var p = a.trim_prefix("--").split("=")
		if p[0] == "out" and p.size() > 1:
			out = p[1]
	DirAccess.make_dir_recursive_absolute(out)
	seed(7)
	# hermetic, in-memory save (never written): tutorial seen, first world partly starred,
	# so tiles show on / off stars and padlocks
	SaveData._cfg = ConfigFile.new()
	SaveData._cfg.set_value("flags", "tutorial_done", true)
	var stars_for := [3, 2, 1, 0]
	for k in stars_for.size():
		if stars_for[k] > 0:
			SaveData._cfg.set_value("stars", str(Levels.order()[k]), stars_for[k])
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for w in Levels.WORLD_ORDER:
		var ids: Array = Levels.levels_in_world_ordered(w)
		if ids.is_empty():
			continue
		var key: String = Levels.WORLDS[w].name.to_lower().replace(" ", "_")
		var first: int = ids[0]
		steps.append([func(): main.start_level(first), 50, "play_" + key])
		steps.append([func():
			main.screens.show_levels(true)
			main.screens._fill_world_page(w), 30, "select_" + key])
	steps.append([func():
		main.start_level(Levels.order()[0])
		main.screens.show_results(Levels.order()[0], 2, 4, 5), 150, "results_2star"])


func _process(_d: float) -> bool:
	frame += 1
	if frame < 20:
		return false
	if wait > 0:
		wait -= 1
		if wait == 0:
			var name: String = steps[0][2]
			root.get_texture().get_image().save_png(out.path_join(name + ".png"))
			print("shot: " + name)
			steps.pop_front()
		return false
	if steps.is_empty():
		quit()
		return true
	steps[0][0].call()
	wait = steps[0][1]
	return false
