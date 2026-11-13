class_name Worker
extends Node2D
## Freddy, the dock worker. He stands on the low step under the loading spot, so the cargo
## from the pile behind him sits right above his head, and he handles it:
##   - takes each piece from the pile and holds it up with both hands
##   - winds up (stressed face, squats / sways with the cargo) while the player pulls back
##   - swings his arms through when the cargo is thrown
##   - happy when it lands in the truck, sad when it misses, relaxed otherwise
## Pure decoration: he follows the cargo, never moves it. No physics, no level changes.
## Drawn in code with anti-aliased edges (navy outline, flat colours).

const INK := ArtPalette.INK
const SKIN := Color("#F6C9A0")
const SKIN_SHADE := Color("#E3A97C")
const HAT := ArtPalette.MINT
const HAT_SHADE := Color("#2BB07A")
const HAT_LIGHT := Color("#A8F2D0")
const VEST := ArtPalette.CORAL
const VEST_SHADE := Color("#B83F1F")
const SHIRT := Color("#5C7BA6")
const PANTS := Color("#3A4F73")
const BOOT := Color("#4A3A33")
const REFLECT := Color("#F2F6FA")
const GLOVE := Color("#F2F0EA")
const SWEAT := Color("#8FD0F5")
const TEETH := Color("#F2F6FA")

const MOOD_HOLD := 1.4    # s a happy / sad face stays after a cargo resolves
const THROW_TIME := 0.38  # s of follow-through after a throw
const HEIGHT := 115.0     # feet to the top of the hard hat (= Game.STEP_Y - Game.DOCK_TOP)
const HIP := Vector2(0, -30)
const SH_FRONT := Vector2(18, -60)  # shoulders (before the body moves)
const SH_BACK := Vector2(-18, -60)
const ARM := 30.0    # upper arm = forearm
const LEG := 14.0    # thigh = shin
const HIP_X := 9.0
const ANKLE := Vector2(10, -6)
const REACH_FROM := -75.0  # he reaches for the cargo once it is this close (local x)

## The worker's name, in case a screen ever wants to show it.
const WORKER_NAME := "Freddy"

var game: Game
var mood := "normal"  # normal | stress | throw | happy | sad
var holding := false

var _hold_mood := ""
var _hold := 0.0
var _t := 0.0
var _blink := 0.0
var _next_blink := 2.0
var _strength := 0.0  # 0..1 how far the cargo is pulled back
var _throw_t := 0.0
var _throw_dir := Vector2(0.8, -0.6)
var _last_dir := Vector2(0.8, -0.6)
var _seen_thrown := 0
var _off := Vector2.ZERO  # upper body offset: follows the cargo (squat / sway)
var _bob := 0.0
var _lean := 0.0
var _shake := 0.0
var _hand_f := SH_FRONT + Vector2(6, 46)
var _hand_b := SH_BACK + Vector2(-6, 46)


func setup(g: Game):
	game = g
	z_index = 2  # in front of the dock and of the cargo he holds (gloves on the box)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	position = Vector2(Game.FLICK_X, Game.STEP_Y)
	_seen_thrown = game.thrown
	game.cargo_resolved.connect(_on_cargo_resolved)


func _on_cargo_resolved(_kind: String, ok: bool, _reason: String):
	_hold_mood = "happy" if ok else "sad"
	_hold = MOOD_HOLD


func _process(delta: float):
	if game == null:
		return
	_t += delta
	_hold = max(0.0, _hold - delta)
	_throw_t = max(0.0, _throw_t - delta)
	var aiming: bool = game.aiming and game.pull.length() >= 6.0
	_strength = clamp(game.pull.length() / Game.MAX_PULL, 0.0, 1.0) if aiming else 0.0
	if aiming:
		_last_dir = game.pull.normalized()
	if game.thrown != _seen_thrown:
		_seen_thrown = game.thrown
		_throw_t = THROW_TIME
		_throw_dir = _last_dir
	var box: Cargo = game.current
	if box != null and not is_instance_valid(box):
		box = null
	# bottom-centre of the cargo, in his space (at rest it is exactly the top of his hat)
	var under := Vector2(0, -HEIGHT)
	if box != null:
		under = to_local(box.global_position) + Vector2(0, box.half_height())
	holding = box != null and under.x > REACH_FROM

	if _throw_t > 0.0:
		mood = "throw"
	elif aiming:
		mood = "stress"
	elif _hold > 0.0:
		mood = _hold_mood
	else:
		mood = "normal"

	# body: the upper body follows the cargo (squats when it is pulled down, sways back with it)
	var want := Vector2.ZERO
	_bob = 0.0
	_lean = 0.0
	_shake = 0.0
	if holding:
		var d := under - Vector2(0, -HEIGHT)
		if game.current_ready:
			want = Vector2(clamp(d.x * 0.8, -22.0, 8.0), clamp(d.y, -5.0, 15.0))
		else:
			want = Vector2(clamp(d.x * 0.25, -12.0, 0.0), 0.0)  # leans toward the incoming cargo
	match mood:
		"normal":
			if not holding:
				_bob = sin(_t * 2.2) * 1.2
		"stress":
			_lean = -0.04 - 0.06 * _strength
			_shake = sin(_t * 55.0) * (0.5 + 1.3 * _strength)
		"throw":
			var k := 1.0 - _throw_t / THROW_TIME
			var swing := sin(min(k * 1.4, 1.0) * PI * 0.5) * (1.0 - 0.5 * k)
			_lean = 0.2 * swing
			want = Vector2(7.0, -2.0) * swing
		"happy":
			_bob = -abs(sin(_t * 9.0)) * (2.5 if holding else 8.0)  # little hops
		"sad":
			_bob = 2.5 if holding else 3.0 + sin(_t * 1.6) * 0.8
			_lean = 0.04
	_off = _off.lerp(want, 1.0 - exp(-delta * 30.0))
	_bob = clamp(_bob, -8.0, 15.0 - _off.y)

	# hands: under the cargo while he holds it, otherwise posed by the mood
	var sf := _upper(SH_FRONT)
	var sb := _upper(SH_BACK)
	var tf := Vector2.ZERO
	var tb := Vector2.ZERO
	if holding:
		var grip: float = clamp(float(box.info.size.x) * 0.5 - 9.0, 9.0, 20.0)
		tf = under + Vector2(grip, 3.0)
		tb = under + Vector2(-grip, 3.0)
	elif mood == "throw":
		tf = sf + _throw_dir * 52.0
		tb = sb + _throw_dir.rotated(-0.25) * 50.0
	elif mood == "happy":
		var w := sin(_t * 18.0) * 4.0
		tf = sf + Vector2(18.0 + w, -38.0 + w)
		tb = sb + Vector2(-18.0 + w, -38.0 - w)
	elif mood == "sad":
		tf = sf + Vector2(2.0, 50.0)
		tb = sb + Vector2(-2.0, 50.0)
	else:
		var sway := sin(_t * 2.2) * 1.5
		tf = sf + Vector2(7.0, 46.0 + sway)
		tb = sb + Vector2(-7.0, 46.0 + sway)
	var rate := 1.0 - exp(-delta * (45.0 if holding else 22.0))
	_hand_f = _reach(sf, _hand_f.lerp(tf, rate))
	_hand_b = _reach(sb, _hand_b.lerp(tb, rate))

	# blink every few seconds (normal face only)
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.14
		_next_blink = randf_range(2.0, 4.5)
	_blink = max(0.0, _blink - delta)
	queue_redraw()


## Upper-body point after the lean (pivot at the hips), the cargo-follow offset, bob and shake.
func _upper(p: Vector2) -> Vector2:
	return HIP + (p - HIP).rotated(_lean) + _off + Vector2(_shake, _bob)


## Keeps a hand within arm's length of its shoulder.
func _reach(shoulder: Vector2, hand: Vector2) -> Vector2:
	var v := hand - shoulder
	var max_len := 2.0 * ARM - 1.0
	if v.length() > max_len:
		return shoulder + v.normalized() * max_len
	if v.length() < 8.0:
		return shoulder + Vector2(0, 8)
	return hand


## Middle joint (elbow / knee) of a two-bone limb from a to b; it bends toward `prefer`.
static func _joint(a: Vector2, b: Vector2, bone: float, prefer: Vector2) -> Vector2:
	var v := b - a
	var d: float = clamp(v.length(), 1.0, 2.0 * bone - 0.5)
	var dir := v.normalized() if v.length() > 0.01 else Vector2.DOWN
	var h := sqrt(max(bone * bone - d * d * 0.25, 0.0))
	var perp := Vector2(-dir.y, dir.x)
	var mid := a + dir * d * 0.5
	return mid + perp * h if perp.dot(prefer) >= 0.0 else mid - perp * h


func _draw():
	_draw_legs()
	# upper body: follows the cargo, pivots at the hips
	draw_set_transform(_off + Vector2(_shake, _bob) + HIP - HIP.rotated(_lean), _lean, Vector2.ONE)
	_draw_torso()
	_draw_head()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# arms last: the gloves sit on the cargo
	_draw_arm(_upper(SH_BACK), _hand_b, Vector2(-1.0, 0.35))
	_draw_arm(_upper(SH_FRONT), _hand_f, Vector2(1.0, 0.35))


# ---------------------------------------------------------------- anti-aliased shapes
static func _circle_pts(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func _fill(n: CanvasItem, pts: PackedVector2Array, col: Color):
	if pts.size() < 3:
		return
	n.draw_colored_polygon(pts, col)
	var edge := PackedVector2Array(pts)
	edge.append(pts[0])
	n.draw_polyline(edge, col, 1.2, true)  # soft edge


static func _disc(n: CanvasItem, c: Vector2, r: float, col: Color):
	if r > 0.3:
		_fill(n, _circle_pts(c, r), col)


static func _ink_disc(n: CanvasItem, c: Vector2, r: float, fill: Color, w := 3.0):
	_disc(n, c, r, INK)
	_disc(n, c, r - w, fill)


static func _ink_poly(n: CanvasItem, pts: PackedVector2Array, fill: Color, w := 3.0):
	_fill(n, pts, INK)
	_fill(n, ArtDraw.inset(pts, w), fill)


## Round-ended stroke.
static func _stroke(n: CanvasItem, a: Vector2, b: Vector2, col: Color, width: float):
	if a.distance_to(b) > 0.5:
		n.draw_line(a, b, col, width, true)
	_disc(n, a, width * 0.5, col)
	_disc(n, b, width * 0.5, col)


# ---------------------------------------------------------------- body parts
## Legs with knees: the feet stay planted, the hips move with the upper body (squat).
func _draw_legs():
	for s: float in [-1.0, 1.0]:
		var hip := _upper(HIP + Vector2(s * HIP_X, 0))
		var ankle := Vector2(s * ANKLE.x, ANKLE.y)
		var knee := _joint(hip, ankle, LEG, Vector2(s, 0))
		_stroke(self, hip, knee, INK, 15.0)
		_stroke(self, knee, ankle, INK, 15.0)
		_stroke(self, hip, knee, PANTS, 9.0)
		_stroke(self, knee, ankle, PANTS, 9.0)
		ArtDraw.ink_rect(self, Rect2(ankle.x - 8.0 + s * 1.5, -10, 17, 10), BOOT, 3.0, 4.0)


func _draw_torso():
	# hi-vis vest, wide at the shoulders
	_ink_poly(self, PackedVector2Array([Vector2(-20, -66), Vector2(20, -66), Vector2(16, -26), Vector2(-16, -26)]), VEST, 3.5)
	draw_rect(Rect2(-15.5, -33, 31, 3.5), VEST_SHADE)
	# reflective band, zip, shirt collar
	draw_colored_polygon(PackedVector2Array([Vector2(-17.6, -46), Vector2(17.6, -46), Vector2(17.1, -41), Vector2(-17.1, -41)]), REFLECT)
	draw_line(Vector2(0, -52), Vector2(0, -29.5), INK, 2.0, true)
	_ink_poly(self, PackedVector2Array([Vector2(-7, -64.5), Vector2(7, -64.5), Vector2(0, -49)]), SHIRT, 2.0)
	# neck
	ArtDraw.ink_rect(self, Rect2(-6, -75, 12, 12), SKIN_SHADE, 3.0)


## Two-bone bare arm (shoulder, elbow, work glove); the elbow bends toward `prefer`.
func _draw_arm(sh: Vector2, hand: Vector2, prefer: Vector2):
	var elbow := _joint(sh, hand, ARM, prefer)
	_stroke(self, sh, elbow, INK, 16.0)
	_stroke(self, elbow, hand, INK, 14.0)
	_stroke(self, sh, elbow, SKIN, 10.0)
	_stroke(self, elbow, hand, SKIN, 8.0)
	# glove with a cuff
	var g := Rect2(hand.x - 9.0, hand.y - 6.5, 18, 13)
	ArtDraw.ink_rect(self, g, GLOVE, 2.8, 5.0)
	draw_line(Vector2(g.position.x + 3, g.end.y - 4), Vector2(g.end.x - 3, g.end.y - 4), INK, 1.6, true)


func _draw_head():
	# square-jawed head
	ArtDraw.ink_rect(self, Rect2(-16, -103, 33, 32), SKIN, 3.5, 9.0)
	draw_arc(Vector2(0.5, -88), 13.0, 0.5, PI - 0.5, 12, Color(SKIN_SHADE, 0.75), 3.0, true)  # jaw shade
	# hard hat with a front brim; its top is exactly HEIGHT above his feet
	var hat := PackedVector2Array([Vector2(-19, -93.5)])
	for i in 17:
		var a := PI + PI * i / 16.0
		hat.append(Vector2(cos(a) * 19.0, -103.0 + sin(a) * 12.0))
	hat.append_array(PackedVector2Array([Vector2(19, -99), Vector2(29, -97), Vector2(29, -93.5)]))
	_ink_poly(self, hat, HAT, 3.5)
	draw_line(Vector2(-14.5, -100), Vector2(17.5, -100), HAT_SHADE, 3.0, true)
	draw_arc(Vector2(0, -103), 13.0, PI + 0.55, PI + 1.2, 8, HAT_LIGHT, 2.6, true)
	_draw_face(Vector2(1.0, -84.0))


## c = the point between his eyes.
func _draw_face(c: Vector2):
	var le := c + Vector2(-4.0, 0)
	var re := c + Vector2(10.0, 0)
	var m := c + Vector2(3.0, 8.5)  # mouth
	match mood:
		"normal":
			if _blink > 0.0:
				draw_line(le + Vector2(-3, 0), le + Vector2(3, 0), INK, 2.2, true)
				draw_line(re + Vector2(-3, 0), re + Vector2(3, 0), INK, 2.2, true)
			else:
				_disc(self, le, 2.5, INK)
				_disc(self, re, 2.5, INK)
			draw_line(le + Vector2(-3.5, -5.5), le + Vector2(3, -6), INK, 2.0, true)
			draw_line(re + Vector2(-3, -6), re + Vector2(3.5, -5.5), INK, 2.0, true)
			draw_arc(m + Vector2(0, -3.5), 5.5, 0.55, PI - 0.55, 10, INK, 2.2, true)
		"stress":
			# wide eyes, furrowed brows, gritted teeth, one sweat drop
			for e in [le, re]:
				_ink_disc(self, e, 4.4, Color.WHITE, 1.6)
				_disc(self, e + Vector2(0.8 + 0.6 * _strength, 0.3), 1.5, INK)
			draw_line(le + Vector2(-4.5, -7.5), le + Vector2(4, -5), INK, 2.5, true)
			draw_line(re + Vector2(4.5, -7.5), re + Vector2(-4, -5), INK, 2.5, true)
			var mr := Rect2(m.x - 5.5, m.y - 2.5, 11, 6)
			ArtDraw.ink_rect(self, mr, TEETH, 1.8, 2.0)
			draw_line(Vector2(mr.position.x + 1.5, m.y + 0.5), Vector2(mr.end.x - 1.5, m.y + 0.5), INK, 1.1, true)
			var k := fmod(_t * 1.8, 1.0)
			_drop(Vector2(c.x + 23, c.y - 6 + 16 * k), 1.0 - k * 0.7)
		"throw":
			# set jaw: brows down, small open mouth
			_disc(self, le, 2.5, INK)
			_disc(self, re, 2.5, INK)
			draw_line(le + Vector2(-4, -6.5), le + Vector2(3.5, -4.5), INK, 2.4, true)
			draw_line(re + Vector2(4, -6.5), re + Vector2(-3.5, -4.5), INK, 2.4, true)
			_disc(self, m, 3.2, INK)
		"happy":
			# raised brows and a grin
			_disc(self, le, 2.5, INK)
			_disc(self, re, 2.5, INK)
			draw_line(le + Vector2(-3.5, -7), le + Vector2(3, -8), INK, 2.0, true)
			draw_line(re + Vector2(-3, -8), re + Vector2(3.5, -7), INK, 2.0, true)
			var grin := PackedVector2Array()
			for i in 11:
				var a := PI * i / 10.0
				grin.append(m + Vector2(cos(a) * 6.5, sin(a) * 5.5 - 2.0))
			_ink_poly(self, grin, TEETH, 1.8)
		"sad":
			# brows tilted up in the middle, eyes down, small frown
			_disc(self, le + Vector2(0, 1), 2.4, INK)
			_disc(self, re + Vector2(0, 1), 2.4, INK)
			draw_line(le + Vector2(-4, -4.5), le + Vector2(3.5, -7), INK, 2.2, true)
			draw_line(re + Vector2(4, -4.5), re + Vector2(-3.5, -7), INK, 2.2, true)
			draw_arc(m + Vector2(0, 5.5), 5.5, PI + 0.55, TAU - 0.55, 10, INK, 2.2, true)


## A sweat drop.
func _drop(p: Vector2, a: float):
	var tip := PackedVector2Array([p + Vector2(0, -5.5), p + Vector2(2.8, 0), p + Vector2(-2.8, 0)])
	_fill(self, tip, Color(INK, a))
	_disc(self, p + Vector2(0, 1.0), 3.2, Color(INK, a))
	_disc(self, p + Vector2(0, 1.0), 1.9, Color(SWEAT, a))
