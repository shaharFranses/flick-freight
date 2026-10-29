extends Mover
## Dev obstacle for tools/timing_test.sh: a tall wall between dock and truck, down
## (blocking) for 90 frames, up for 90.

var body: AnimatableBody2D


func period_frames() -> int:
	return 180


func _y(f: int) -> float:
	return 140.0 if posmod(f, 180) < 90 else -460.0


func _build():
	body = make_body("block", [Rect2(-30, 0, 60, 480)])


func pose_at(f: int):
	body.position = Vector2(600, _y(f))


func sim_shapes(f: int) -> Array:
	return [Rect2(570, _y(f), 60, 480)]


func _draw():
	draw_rect(Rect2(570, _y(game.frame + phase), 60, 480), Color("#3E4A5C"))
