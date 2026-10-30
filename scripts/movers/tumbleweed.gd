extends Mover
## Desert pusher (a reskinned M22): a tumbleweed blows back and forth between the dock and the
## truck in big bounces that reach up into the throw paths, knocking cargo out of the air.
## cfg: x0, x1 (roll range), period (frames there and back), hop (bounce height), hops (per
##      crossing), radius, phase

var ball: AnimatableBody2D
var x0 := 300.0
var x1 := 900.0
var per := 240
var hop := 60.0
var r := 34.0
var hops := 3


func _build():
	x0 = cfg.get("x0", 300.0)
	x1 = cfg.get("x1", 900.0)
	per = int(cfg.get("period", 240))
	hop = cfg.get("hop", 60.0)
	r = cfg.get("radius", 34.0)
	hops = int(cfg.get("hops", 3))
	ball = AnimatableBody2D.new()
	ball.sync_to_physics = false
	ball.add_to_group("block")
	var cs = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = r
	cs.shape = c
	ball.add_child(cs)
	add_child(ball)


func period_frames() -> int:
	return per


## Bounces from x0 to x1 and back (the wind gusts and turns), `hops` bounces each way.
func _pos(f: int) -> Vector2:
	var k = posmod(f, per) / float(per)
	var u = k * 2.0 if k < 0.5 else 2.0 - k * 2.0  # 0 -> 1 -> 0
	var x = lerp(x0, x1, u)
	var y = Game.ROAD_Y - r - hop * abs(sin(u * PI * hops))
	return Vector2(x, y)


func pose_at(f: int):
	ball.position = _pos(f)


func sim_shapes(f: int) -> Array:
	var p = _pos(f)
	var poly = PackedVector2Array()
	for i in 10:
		poly.append(p + Vector2(cos(TAU * i / 10), sin(TAU * i / 10)) * r)
	return [poly]


func _draw():
	var f = game.frame + phase
	var p = _pos(f)
	var spin = TAU * f / 40.0
	draw_circle(p, r + 3, Color(0.106, 0.165, 0.255, 0.85))
	draw_circle(p, r, Color("#C9A86B"))
	for i in 7:
		var a = spin + TAU * i / 7
		draw_arc(p + Vector2(cos(a), sin(a)) * r * 0.35, r * 0.55, a, a + PI, 10, Color("#8A6A3A"), 3.0)
