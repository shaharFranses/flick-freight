extends SceneTree
## Prints the number of levels (for shell tools).
func _init():
	print("COUNT %d" % Levels.count())
	quit()
