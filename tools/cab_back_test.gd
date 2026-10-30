extends SceneTree
## Regression test: cargo resting in the bed against the back of the cab (flatbed, level 93)
## is delivered, not a "cab" miss.

var main: Node
const LEVEL := 92
var t := 0.0
var t_throw := -1.0
var placed := false
var box: Cargo


func _init():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.PATH))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	t += 1.0 / 60.0
	var g: Game = main.game
	if g == null:
		return false
	if g.level_index != LEVEL:
		main.start_level(LEVEL)
		return false
	if t_throw < 0 and g.can_aim():
		box = g.current
		box.resolved.connect(_on_resolved, CONNECT_ONE_SHOT)
		g.throw_with_pull(Vector2(40, -40))
		t_throw = t
	elif t_throw > 0 and not placed:
		# drop it on the bed, sliding into the back of the cab
		var tr = g.live_trucks()[0]
		var c: Cargo = box
		var half = c.info.size * 0.5
		var p = tr.to_global(Vector2(156 - half.x - 2, -half.y - 1))
		PhysicsServer2D.body_set_state(c.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0, p))
		PhysicsServer2D.body_set_state(c.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(120, 0))
		placed = true
	elif t_throw > 0 and t - t_throw > 8.0:
		print("FAIL: no resolve within 8s")
		quit(1)
	return false


func _on_resolved(c: Cargo, ok: bool, reason: String):
	var tr = c.game.live_trucks()[0]
	print("%s: delivered=%s reason=%s at local %s" % ["PASS" if ok else "FAIL", ok, reason, tr.to_local(c.global_position)])
	print("CAB BACK TEST: %d failure(s)" % (0 if ok else 1))
	quit(0 if ok else 1)
