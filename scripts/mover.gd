class_name Mover
extends Node2D
## A moving obstacle (Plan 2 §3.2). Its pose is a pure function of the level clock
## (Game.frame + phase): nothing integrates its own state, so every restart plays out
## identically and the bot can look ahead. Parts cargo can touch are AnimatableBody2D
## (sync_to_physics), so cargo resting on or pushed by them behaves.
##
## Level data: "movers": [{"type": "<id>", "phase": frames, ...type params}]

var game  # Game
var cfg: Dictionary
var phase := 0  # phase_offset_frames


func setup(g, c: Dictionary):
	game = g
	cfg = c
	phase = int(c.get("phase", 0))
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_build()
	pose_at(phase)


## Frames for one full cycle (0 = never repeats / static).
func period_frames() -> int:
	return 0


## Put everything where it is at clock frame `f` (already includes the phase).
func pose_at(_f: int):
	pass


## For the bot: solid shapes at clock frame `f` (phase included), in world space.
## Each entry is a Rect2 or a PackedVector2Array polygon.
func sim_shapes(_f: int) -> Array:
	return []


## For the bot: velocity a cargo resting on / pushed by this mover gets at frame f, at p.
func sim_carry(_f: int, _p: Vector2) -> Vector2:
	return Vector2.ZERO


func _build():
	pass


func _physics_process(_delta: float):
	if game:
		pose_at(game.frame + phase)
		queue_redraw()


# ---------------------------------------------------------------- helpers
## A solid body that moves by script (cargo collides with it as with a moving wall).
func make_body(group: String, shapes: Array, bounce := 0.1, friction := 0.8) -> AnimatableBody2D:
	var b = AnimatableBody2D.new()
	b.sync_to_physics = true
	b.add_to_group(group)
	var pm = PhysicsMaterial.new()
	pm.bounce = bounce
	pm.friction = friction
	b.physics_material_override = pm
	for sh in shapes:
		var cs = CollisionShape2D.new()
		if sh is Rect2:
			var rs = RectangleShape2D.new()
			rs.size = sh.size
			cs.shape = rs
			cs.position = sh.get_center()
		else:
			var cp = ConvexPolygonShape2D.new()
			cp.points = sh
			cs.shape = cp
		b.add_child(cs)
	add_child(b)
	return b


static func sine(f: int, period: int) -> float:
	return sin(TAU * f / float(period))
