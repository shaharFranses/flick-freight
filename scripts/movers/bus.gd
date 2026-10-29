extends Mover
## M18: a bus (or train) driving through the front lane at intervals. It only stops cargo
## that's in the air (cargo already loaded is safe): while it passes, throws hit it.
## Warning lights flash and a horn sounds before it arrives.
## cfg: kind ("bus" / "train"), length, height, speed (px/frame), period, phase, dir (-1 = to the left)

var body: AnimatableBody2D
var length := 380.0
var height := 150.0
var speed := 9.0
var per := 420
var dir := -1.0
var kind := "bus"


func _build():
	kind = cfg.get("kind", "bus")
	length = cfg.get("length", 380.0 if kind == "bus" else 900.0)
	height = cfg.get("height", 150.0 if kind == "bus" else 130.0)
	speed = cfg.get("speed", 9.0 if kind == "bus" else 14.0)
	per = int(cfg.get("period", 420))
	dir = cfg.get("dir", -1.0)
	z_index = 6  # front lane
	body = make_body("block", [Rect2(0, -height, length, height)])
	body.collision_layer = Game.LAYER_FLIGHT
	body.collision_mask = 0
	game.flying_mask |= Game.LAYER_FLIGHT


func period_frames() -> int:
	return per


const LEAD := 60  # frames of warning (lights + horn) before it drives on screen


## Left edge x at frame f: each cycle starts with LEAD frames of warning, then it drives
## across from off-screen to off-screen.
func _x(f: int) -> float:
	var k = posmod(f, per) - LEAD
	if dir < 0:
		return 1300.0 - k * speed
	return -20.0 - length + k * speed


func _on_screen(f: int) -> bool:
	var x = _x(f)
	return x < 1280 and x + length > 0


func _warning(f: int) -> bool:
	return posmod(f, per) < LEAD or _on_screen(f)


func pose_at(f: int):
	body.position = Vector2(_x(f), Game.ROAD_Y + 4)
	if posmod(f, per) == 0 and game.frame > 0:
		Sfx.play("honk", -6.0, 0.8 if kind == "bus" else 0.6)


func sim_shapes(f: int) -> Array:
	return [Rect2(_x(f), Game.ROAD_Y + 4 - height, length, height)]


func _draw():
	var f = game.frame + phase
	var x = _x(f)
	var y = Game.ROAD_Y + 4
	var navy = Color("#1B2A41")
	# warning beacons at both screen edges
	if _warning(f) and (f / 8) % 2 == 0:
		for bx in [1250.0, 30.0]:
			draw_circle(Vector2(bx, 470), 14, navy)
			draw_circle(Vector2(bx, 470), 10, Color("#FF6B57"))
	if x > 1300 or x + length < -20:
		return
	var r = Rect2(x, y - height, length, height)
	var col = Color("#F2B134") if kind == "bus" else Color("#4F7FB0")
	draw_rect(r.grow(3), navy)
	draw_rect(r, col)
	draw_rect(Rect2(r.position.x, r.end.y - 22, r.size.x, 22), col.darkened(0.25))
	var wx = r.position.x + 16
	while wx < r.end.x - 50:
		draw_rect(Rect2(wx, r.position.y + 16, 40, 38), Color("#BFE7F7"))
		wx += 56
	if kind == "train":
		var cx = r.position.x + 220
		while cx < r.end.x:
			draw_line(Vector2(cx, r.position.y), Vector2(cx, r.end.y), navy, 4.0)
			cx += 220
	for wxx in [r.position.x + 60, r.end.x - 60]:
		draw_circle(Vector2(wxx, y - 4), 22, Color("#2E3440"))
		draw_circle(Vector2(wxx, y - 4), 9, Color("#C9CED6"))
