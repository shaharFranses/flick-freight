extends Mover
## Woods: a tall tree rooted in the ground between the dock and the truck. Its crown sways in
## the wind (scripted, so it's the same every time) and blocks throws: go over it, or slip
## past the crown while it leans away. In a level with wind it leans downwind as it sways.
## cfg: x (trunk), height (ground to crown centre), crown (crown radius), sway (deg each way),
##      period, lean (deg, default: with the level's wind), phase

var body: AnimatableBody2D
var x := 600.0
var height := 330.0
var crown := 80.0
var sway := 8.0
var lean := 0.0
var per := 240
const TRUNK := 26.0
const N := 10  # crown polygon sides


func _build():
	x = cfg.get("x", 600.0)
	height = cfg.get("height", 330.0)
	crown = cfg.get("crown", 80.0)
	sway = deg_to_rad(cfg.get("sway", 8.0))
	per = int(cfg.get("period", 240))
	var w = game.level.get("wind", 0.0) if game else 0.0
	lean = deg_to_rad(cfg.get("lean", 4.0 * signf(w)))
	# local space: origin at the base of the trunk, up is -y
	body = make_body("block", [Rect2(-TRUNK * 0.5, -height, TRUNK, height), _crown_poly()], 0.2, 0.6)
	body.position = Vector2(x, Game.ROAD_Y)


func _crown_poly() -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in N:
		var a = TAU * i / N
		pts.append(Vector2(cos(a) * crown, -height + sin(a) * crown * 0.85))
	return pts


func period_frames() -> int:
	return per


func _angle(f: int) -> float:
	return lean + sway * sine(f, per)


func pose_at(f: int):
	body.rotation = _angle(f)


func sim_shapes(f: int) -> Array:
	var t = Transform2D(_angle(f), Vector2(x, Game.ROAD_Y))
	var trunk = PackedVector2Array([t * Vector2(-TRUNK * 0.5, 0), t * Vector2(TRUNK * 0.5, 0),
		t * Vector2(TRUNK * 0.5, -height), t * Vector2(-TRUNK * 0.5, -height)])
	return [trunk, t * _crown_poly()]


func _draw():
	var f = game.frame + phase
	var navy = Color("#1B2A41")
	draw_set_transform(Vector2(x, Game.ROAD_Y), _angle(f), Vector2.ONE)
	var trunk = Rect2(-TRUNK * 0.5, -height, TRUNK, height)
	draw_rect(trunk.grow(3), navy)
	draw_rect(trunk, Color("#8A5A32"))
	draw_line(Vector2(-4, -40), Vector2(-4, -height + 40), Color("#6E4526"), 3.0)
	draw_line(Vector2(0, -height * 0.55), Vector2(-38, -height * 0.75), Color("#8A5A32"), 8.0)  # branch
	var poly = _crown_poly()
	draw_colored_polygon(Geometry2D.offset_polygon(poly, 3)[0], navy)
	draw_colored_polygon(poly, Color("#2F8F5B"))
	# leafy lumps and a highlight
	for k in 5:
		var a = TAU * k / 5 + 0.4
		draw_circle(Vector2(cos(a) * crown * 0.45, -height + sin(a) * crown * 0.4), crown * 0.38, Color("#38A86A"))
	draw_circle(Vector2(-crown * 0.3, -height - crown * 0.35), crown * 0.25, Color("#5BC488"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
