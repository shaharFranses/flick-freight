extends Mover
## M17: roller garage door between player and vehicle. A wall comes down from the top of
## the screen to the doorway; the door rolls up, holds open, flashes amber, and drops.
## cfg: x (centre), top (doorway top y), period, open (frames fully open), phase

const W := 56.0  # wall thickness
const T := 24  # frames to roll up / down

var door: AnimatableBody2D
var x := 600.0
var top := 300.0
var per := 240
var open := 110


func _build():
	x = cfg.get("x", 600.0)
	top = cfg.get("top", 300.0)
	per = int(cfg.get("period", 240))
	open = int(cfg.get("open", 110))
	make_body("block", [Rect2(x - W * 0.5, -400, W, top + 400)])  # wall above the doorway
	door = make_body("block", [Rect2(x - 12, 0, 24, Game.ROAD_Y - top)])


func period_frames() -> int:
	return per


## 0 = closed, 1 = fully open.
func _openness(f: int) -> float:
	var k = posmod(f, per)
	if k < T:
		return k / float(T)
	if k < T + open:
		return 1.0
	if k < 2 * T + open:
		return 1.0 - (k - T - open) / float(T)
	return 0.0


func _door_y(f: int) -> float:
	return top - _openness(f) * (Game.ROAD_Y - top - 6)


## Amber light: on while the door is about to close or closing.
func _warning(f: int) -> bool:
	var k = posmod(f, per)
	return k >= T + open - 45 and k < 2 * T + open


func pose_at(f: int):
	door.position = Vector2(0, _door_y(f) - top)


func sim_shapes(f: int) -> Array:
	return [Rect2(x - W * 0.5, -400, W, top + 400), Rect2(x - 12, _door_y(f), 24, Game.ROAD_Y - top)]


func _draw():
	var f = game.frame + phase
	var navy = Color("#1B2A41")
	# brick wall above the doorway
	var wall = Rect2(x - W * 0.5, -400, W, top + 400)
	draw_rect(wall.grow(3), navy)
	draw_rect(wall, Color("#B5654A"))
	var y = top - 14
	var row = 0
	while y > -400:
		draw_line(Vector2(wall.position.x, y), Vector2(wall.end.x, y), Color("#8E4B36"), 2.0)
		draw_line(Vector2(x + (8 if row % 2 else -8), y), Vector2(x + (8 if row % 2 else -8), y + 14), Color("#8E4B36"), 2.0)
		y -= 14
		row += 1
	# door: slatted, slides up behind the wall
	var dy = _door_y(f)
	var door_r = Rect2(x - 13, max(dy, top - 10), 26, Game.ROAD_Y - max(dy, top - 10))
	if dy < Game.ROAD_Y - 8:
		draw_rect(door_r.grow(2), navy)
		draw_rect(door_r, Color("#AAB4BF"))
		var sy = door_r.position.y + 6
		while sy < door_r.end.y:
			draw_line(Vector2(door_r.position.x, sy), Vector2(door_r.end.x, sy), Color("#7D8894"), 2.0)
			sy += 10
	# roller housing over the doorway (the door rolls up into it) + warning light
	var housing = Rect2(x - 46, top - 44, 92, 44)
	draw_rect(housing.grow(3), navy)
	draw_rect(housing, Color("#7D8894"))
	draw_rect(Rect2(housing.position.x, housing.end.y - 8, housing.size.x, 8), Color("#F2B134"))
	for k in 3:
		draw_line(Vector2(housing.position.x + 8, housing.position.y + 9 + k * 9),
			Vector2(housing.end.x - 8, housing.position.y + 9 + k * 9), Color("#5B6574"), 2.0)
	var on = _warning(f) and (f / 6) % 2 == 0
	draw_circle(Vector2(x, top - 58), 12, navy)
	draw_circle(Vector2(x, top - 58), 9, Color("#FFB000") if on else Color("#6B5A2E"))
