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
	# the door: from the doorway top to the road when shut; it slides up as one piece
	door = make_body("block", [Rect2(x - 12, top, 24, Game.ROAD_Y - top)])


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
	# door: red and white stripes so it reads at a glance; it rolls up into the housing
	var dy = _door_y(f)
	var bottom = dy + Game.ROAD_Y - top  # the door's lower edge
	var door_r = Rect2(x - 16, top - 10, 32, bottom - (top - 10))
	if bottom > top + 8:
		draw_rect(door_r.grow(3), navy)
		draw_rect(door_r, Color("#F4F4F0"))
		var sy = door_r.position.y + 2
		var k = 0
		while sy < door_r.end.y:
			if k % 2 == 0:
				draw_rect(Rect2(door_r.position.x, sy, door_r.size.x, min(16.0, door_r.end.y - sy)), Color("#E4572E"))
			sy += 16
			k += 1
	# roller housing over the doorway
	var housing = Rect2(x - 46, top - 44, 92, 44)
	draw_rect(housing.grow(3), navy)
	draw_rect(housing, Color("#7D8894"))
	draw_rect(Rect2(housing.position.x, housing.end.y - 8, housing.size.x, 8), Color("#F2B134"))
	for j in 3:
		draw_line(Vector2(housing.position.x + 8, housing.position.y + 9 + j * 9),
			Vector2(housing.end.x - 8, housing.position.y + 9 + j * 9), Color("#5B6574"), 2.0)
	# traffic light: green = open (throw now), amber = moving / about to close, red = shut
	var o = _openness(f)
	var state = 0  # 0 red, 1 amber, 2 green
	if o >= 1.0 and not _warning(f):
		state = 2
	elif o > 0.0 or _warning(f):
		state = 1
	var box = Rect2(x + 52, top - 98, 30, 84)
	draw_rect(box.grow(3), navy)
	draw_rect(box, Color("#2E3440"))
	var lamps = [Color("#FF4B3A"), Color("#FFB000"), Color("#3DDC97")]
	for i in 3:
		var c = Vector2(box.get_center().x, box.position.y + 15 + i * 27)
		var on = i == state  # lamp 0 red, 1 amber, 2 green
		if i == 1 and on:
			on = (f / 6) % 2 == 0  # amber blinks
		draw_circle(c, 11, lamps[i] if on else lamps[i].darkened(0.7))
	if state == 2:
		# a big arrow through the doorway while it's open
		var ay = (top + Game.ROAD_Y) * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(x - 34, ay - 7), Vector2(x + 14, ay - 7), Vector2(x + 14, ay - 18),
			Vector2(x + 38, ay), Vector2(x + 14, ay + 18), Vector2(x + 14, ay + 7), Vector2(x - 34, ay + 7)]), Color(0.24, 0.86, 0.59, 0.8))
