extends VehicleBase
## V7: train flatcar with low stakes. It doesn't park: it rolls across the scene at a steady
## speed (from its own clock, so every restart is identical) and leaves at the far side.
## Whatever it carries out counts. Several flatcars in a level make a train.
## cfg: start (x when the level starts), speed (px/s, negative = to the left), exit (x where it
##      leaves), once (true: no new car comes after it)

const BED := 220.0
const STAKE := 22.0
var start := 1400.0
var speed := -60.0
var exit_x := -300.0


func _define(cfg: Dictionary) -> Dictionary:
	start = cfg.get("start", 1400.0)
	speed = cfg.get("speed", -60.0)
	exit_x = cfg.get("exit", -300.0)
	var half = BED * 0.5
	return {
		"zone": Rect2(-half + 2, -300, BED - 4, 300),
		"floor_w": BED,
		"floor": Rect2(-half, 0, BED, 16),
		"rear": Rect2(-half - 6, -STAKE, 6, STAKE),
		"walls": [Rect2(half, -STAKE, 6, STAKE)],
		"front": [],
		"reach": Rect2(-half - 40, -320, BED + 80, 340),
		"ride": 64.0,
		"wheels": [[Vector2(-half + 36, 40), 22.0], [Vector2(-half + 84, 40), 22.0],
			[Vector2(half - 84, 40), 22.0], [Vector2(half - 36, 40), 22.0]],
	}


func arrive():
	state = "parked"  # a target from the start: it's already rolling
	_t = 0.0
	position.x = start
	_last_x = position.x
	reset_physics_interpolation()
	arrived.emit()


## A full car doesn't drive off on its own: it straps its load down and keeps rolling.
func leave():
	glue_all()


func _physics_process(delta: float):
	if state == "parked":
		_t += delta
		position.x = start + speed * _t
		if (speed < 0 and position.x < exit_x) or (speed > 0 and position.x > exit_x):
			glue_all()
			state = "away"
			for l in loads:
				if is_instance_valid(l.cargo):
					l.cargo.queue_free()
			departed.emit()
			queue_free()
			return
	for l in loads:
		var c: Cargo = l.cargo
		if is_instance_valid(c) and c.freeze:
			c.global_position = global_position + l.offset
			c.rotation = l.rot
	var dx = position.x - _last_x
	_last_x = position.x
	velocity_x = dx / delta if delta > 0 else 0.0
	for w in wheel_nodes:
		w.rotation += dx / 22.0


func predict_pose(dt: float) -> Array:
	return [Vector2(start + speed * (_t + dt), global_position.y), 0.0]


func predict_vx(_dt: float) -> float:
	return speed


func sim_profile() -> Dictionary:
	var pr = super.sim_profile()
	pr["exit_x"] = exit_x  # the bot won't aim at a car that leaves before the cargo settles
	return pr


func _draw_front(n: Node2D):
	var half = BED * 0.5
	n.draw_rect(Rect2(-half - 4, 0, BED + 8, 20), NAVY)
	n.draw_rect(Rect2(-half, 2, BED, 12), Color("#7F8EA3"))
	for x in [-half - 6, half]:
		n.draw_rect(Rect2(x, -STAKE, 6, STAKE), NAVY)
	n.draw_rect(Rect2(-half - 20, 8, 16, 8), NAVY)  # couplers
	n.draw_rect(Rect2(half + 4, 8, 16, 8), NAVY)
