extends Mover
## M20: a log hung on two ropes swings back and forth across the throw path. Both ropes swing
## together, so the log stays level while it sweeps: it's a pusher that knocks cargo off course.
## cfg: x (centre of the two anchors), y (anchor height), length (rope), swing (deg), period,
##      log (log length), phase

var log_body: AnimatableBody2D
var px := 640.0
var py := 120.0
var rope := 220.0
var swing := 35.0
var per := 200
var log_len := 160.0
const LOG_H := 34.0


func _build():
	px = cfg.get("x", 640.0)
	py = cfg.get("y", 120.0)
	rope = cfg.get("length", 220.0)
	swing = deg_to_rad(cfg.get("swing", 35.0))
	per = int(cfg.get("period", 200))
	log_len = cfg.get("log", 160.0)
	log_body = make_body("block", [Rect2(-log_len * 0.5, -LOG_H * 0.5, log_len, LOG_H)], 0.25, 0.6)


func period_frames() -> int:
	return per


## Centre of the log at frame f.
func _centre(f: int) -> Vector2:
	var a = swing * sine(f, per)
	return Vector2(px, py) + Vector2(sin(a), cos(a)) * rope


func pose_at(f: int):
	log_body.position = _centre(f)
	# the moment it's at the top of its swing: a creak (the tell)
	if posmod(f, per) == per / 4 or posmod(f, per) == 3 * per / 4:
		if game.frame > 0:
			Sfx.play("rim", -14.0, 0.5)


func sim_shapes(f: int) -> Array:
	var c = _centre(f)
	return [Rect2(c.x - log_len * 0.5, c.y - LOG_H * 0.5, log_len, LOG_H)]


func _draw():
	var f = game.frame + phase
	var navy = Color("#1B2A41")
	var c = _centre(f)
	# branch the ropes hang from
	draw_rect(Rect2(px - log_len * 0.5 - 40, py - 16, log_len + 80, 18).grow(3), navy)
	draw_rect(Rect2(px - log_len * 0.5 - 40, py - 16, log_len + 80, 18), Color("#7A4E2A"))
	for s in [-1.0, 1.0]:
		var anchor = Vector2(px + s * log_len * 0.35, py)
		var end = c + Vector2(s * log_len * 0.35, -LOG_H * 0.5)
		draw_line(anchor, end, Color("#C9A877"), 4.0)
	var r = Rect2(c.x - log_len * 0.5, c.y - LOG_H * 0.5, log_len, LOG_H)
	draw_rect(r.grow(3), navy)
	draw_rect(r, Color("#A87444"))
	draw_line(Vector2(r.position.x + 10, c.y - 4), Vector2(r.end.x - 30, c.y - 4), Color("#7A4E2A"), 3.0)
	draw_line(Vector2(r.position.x + 40, c.y + 7), Vector2(r.end.x - 10, c.y + 7), Color("#7A4E2A"), 3.0)
	for e in [r.position.x, r.end.x]:
		draw_circle(Vector2(e, c.y), LOG_H * 0.5, navy)
		draw_circle(Vector2(e, c.y), LOG_H * 0.5 - 3, Color("#D9B98C"))
		draw_arc(Vector2(e, c.y), LOG_H * 0.25, 0, TAU, 12, Color("#A87444"), 2.0)
