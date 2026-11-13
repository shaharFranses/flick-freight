class_name Worker
extends Node2D
## Freddy, the dock worker. He stands right behind the loading spot and handles the cargo:
##   - grabs each piece as it comes off the conveyor and lifts it over his head
##   - winds up (stressed face) while the player pulls back
##   - throws it from up there, arms swinging through
##   - happy when it lands in the truck, sad when it misses, relaxed otherwise
## Pure decoration: the lift is a picture-only offset (Cargo.set_lift). The cargo's body, its
## launch point and timing are untouched, so no level changes. A thrown cargo's picture joins
## its true path within JOIN_TIME; the aim guide is drawn with the same offset.
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
const CHEEK := Color("#FF9AA2")
const SWEAT := Color("#8FD0F5")
const MOUTH := Color("#7A2E3A")

const MOOD_HOLD := 1.4    # s a happy / sad face stays after a cargo resolves
const THROW_TIME := 0.38  # s of follow-through after a throw
const HIP := Vector2(0, -26)
const SH_FRONT := Vector2(11, -58)  # shoulders (before the lean)
const SH_BACK := Vector2(-5, -58)
const ARM_UPPER := 28.0
const ARM_LOWER := 29.0
const OVERHEAD_Y := -110.0  # bottom of the cargo when it is held up (just above the hat)
const LIFT_TIME := 0.28     # s to hoist the cargo up
const JOIN_TIME := 0.22     # s for a thrown cargo's picture to join its true path
const REACH_FROM := -45.0  # he grabs the cargo once it has slid this close (local x)

## The worker's name, in case a screen ever wants to show it.
const WORKER_NAME := "Freddy"

var game: Game
var mood := "normal"  # normal | stress | throw | happy | sad
var holding := false
var arms: Node2D  # drawn above the cargo, so his gloves sit on the box
## Picture offset of the cargo he holds right now (world space; zero when not holding).
var lift := Vector2.ZERO

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
var _bob := 0.0
var _lean := 0.0
var _shake := 0.0
var _hand_f := SH_FRONT + Vector2(2, 44)
var _hand_b := SH_BACK + Vector2(-2, 44)
var _box_prev: Cargo = null
var _lift_k := 0.0
var _fly: Cargo = null  # thrown cargo whose picture is still joining its path
var _fly_off := Vector2.ZERO
var _fly_t := 0.0


## 1 -> 0 over JOIN_TIME: how much of the lift a thrown cargo (or a guide dot) still shows.
static func join(t: float) -> float:
	var k: float = clamp(1.0 - t / JOIN_TIME, 0.0, 1.0)
	return k * k


func setup(g: Game):
	game = g
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	position = Vector2(200, Game.DOCK_TOP)
	arms = Node2D.new()
	arms.z_index = 2
	arms.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	arms.draw.connect(_draw_arms)
	add_child(arms)
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
	var box: Cargo = game.current
	if box != null and not is_instance_valid(box):
		box = null
	if game.thrown != _seen_thrown:
		_seen_thrown = game.thrown
		_throw_t = THROW_TIME
		_throw_dir = _last_dir
		# the cargo he was holding is now in the air: its picture leaves from overhead
		_fly = _box_prev
		_fly_off = lift
		_fly_t = 0.0
	if box != _box_prev:
		_lift_k = 0.0
	_box_prev = box
	if _fly != null:
		_fly_t += delta
		if not is_instance_valid(_fly):
			_fly = null
		elif _fly_t >= JOIN_TIME:
			_fly.set_lift(Vector2.ZERO)
			_fly = null
		else:
			_fly.set_lift(_fly_off * join(_fly_t))
	var box_at := Vector2.ZERO
	if box != null:
		box_at = to_local(box.global_position)
	holding = box != null and box_at.x > REACH_FROM

	if _throw_t > 0.0:
		mood = "throw"
	elif aiming:
		mood = "stress"
	elif _hold > 0.0:
		mood = _hold_mood
	else:
		mood = "normal"

	# body pose
	_bob = 0.0
	_lean = 0.0
	_shake = 0.0
	match mood:
		"normal":
			_bob = sin(_t * 2.2) * 1.2
			if holding:
				_lean = 0.04
		"stress":
			_lean = -0.08 - 0.15 * _strength  # leans back, winding up
			_shake = sin(_t * 55.0) * (0.6 + 1.6 * _strength)
		"throw":
			var k := 1.0 - _throw_t / THROW_TIME
			_lean = 0.26 * sin(min(k * 1.4, 1.0) * PI * 0.5) * (1.0 - 0.5 * k)
		"happy":
			_bob = -abs(sin(_t * 9.0)) * (4.0 if holding else 9.0)  # little hops
		"sad":
			_bob = 3.0 + sin(_t * 1.6) * 0.8
			_lean = 0.06

	# the cargo's picture: hoisted from the belt to over his head (the body stays put)
	lift = Vector2.ZERO
	var vis := box_at
	if holding:
		_lift_k = min(1.0, _lift_k + delta / LIFT_TIME)
		var e := _lift_k * _lift_k * (3.0 - 2.0 * _lift_k)
		var over := _upper(Vector2(3.0, OVERHEAD_Y - box.half_height()))
		if game.current_ready:
			over += box_at - to_local(game.rest_pos)  # follows the pull-back
		vis = box_at.lerp(over, e)
		lift = vis - box_at
	if box != null:
		box.set_lift(lift)

	# hands: under the cargo while he holds it, otherwise posed by the mood
	var sf := _upper(SH_FRONT)
	var sb := _upper(SH_BACK)
	var tf := Vector2.ZERO
	var tb := Vector2.ZERO
	if holding:
		var hw: float = min(float(box.info.size.x) * 0.5 - 6.0, 20.0)
		var hh: float = box.half_height()
		tf = vis + Vector2(hw, hh - 2.0)
		tb = vis + Vector2(-hw, hh - 2.0)
	elif mood == "throw":
		tf = sf + _throw_dir * 46.0
		tb = sb + _throw_dir.rotated(0.4) * 42.0
	elif mood == "happy":
		var w := sin(_t * 18.0) * 4.0
		tf = sf + Vector2(16.0 + w, -38.0 + w)
		tb = sb + Vector2(-18.0 + w, -38.0 - w)
	elif mood == "sad":
		tf = sf + Vector2(3.0, 46.0)
		tb = sb + Vector2(-3.0, 46.0)
	else:
		var sway := sin(_t * 2.2) * 1.5
		tf = sf + Vector2(6.0, 44.0 + sway)
		tb = sb + Vector2(-6.0, 44.0 + sway)
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
	arms.queue_redraw()


## Upper-body point after the lean (pivot at the hips), bob and shake.
func _upper(p: Vector2) -> Vector2:
	return HIP + (p - HIP).rotated(_lean) + Vector2(_shake, _bob)


## Keeps a hand within arm's length of its shoulder.
func _reach(shoulder: Vector2, hand: Vector2) -> Vector2:
	var v := hand - shoulder
	var max_len := ARM_UPPER + ARM_LOWER - 1.0
	if v.length() > max_len:
		return shoulder + v.normalized() * max_len
	if v.length() < 8.0:
		return shoulder + Vector2(0, 8)
	return hand


func _draw():
	draw_set_transform(Vector2(_shake, 0), 0.0, Vector2.ONE)
	_draw_legs()
	# upper body: pivots at the hips so he can lean back / forward
	draw_set_transform(Vector2(_shake, _bob) + HIP - HIP.rotated(_lean), _lean, Vector2.ONE)
	_draw_torso()
	_draw_head()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_arms():
	_draw_arm(arms, _upper(SH_BACK), _hand_b, SHIRT)
	_draw_arm(arms, _upper(SH_FRONT), _hand_f, VEST)


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
	n.draw_line(a, b, col, width, true)
	_disc(n, a, width * 0.5, col)
	_disc(n, b, width * 0.5, col)


# ---------------------------------------------------------------- body parts
func _draw_legs():
	var spread := 0.0
	var step := 0.0
	if mood == "stress":
		spread = 3.0
	elif mood == "throw":
		step = 7.0  # front foot steps into the throw
	for s in [-1, 1]:
		var x: float = s * (8.0 + spread) - 6.0 + (step if s == 1 else 0.0)
		ArtDraw.ink_rect(self, Rect2(x, -28, 12, 24), PANTS, 3.0, 3.0)
		ArtDraw.ink_rect(self, Rect2(x - 1, -9, 18, 10), BOOT, 3.0, 4.0)
		draw_line(Vector2(x + 3, -2.5), Vector2(x + 14, -2.5), INK, 1.6, true)  # sole


func _draw_torso():
	ArtDraw.ink_rect(self, Rect2(-18, -64, 36, 42), SHIRT, 3.5, 7.0)
	# hi-vis vest: two panels, the shirt shows in the middle
	_ink_poly(self, PackedVector2Array([Vector2(-18, -62), Vector2(-16, -64), Vector2(-5, -64), Vector2(-3, -22), Vector2(-18, -22)]), VEST, 3.0)
	_ink_poly(self, PackedVector2Array([Vector2(18, -62), Vector2(16, -64), Vector2(5, -64), Vector2(3, -22), Vector2(18, -22)]), VEST, 3.0)
	# reflective stripes, hem shade
	draw_rect(Rect2(-15, -45, 11, 5), REFLECT)
	draw_rect(Rect2(4, -45, 11, 5), REFLECT)
	draw_rect(Rect2(-15, -29, 12, 4), VEST_SHADE)
	draw_rect(Rect2(3, -29, 12, 4), VEST_SHADE)
	# name tag
	ArtDraw.ink_rect(self, Rect2(5, -59, 10, 8), REFLECT, 1.6, 2.0)
	draw_line(Vector2(7.5, -55), Vector2(12.5, -55), INK, 1.2, true)


## Two-segment arm (shoulder, elbow, glove). Draws on `n` in the worker's local space.
func _draw_arm(n: CanvasItem, sh: Vector2, hand: Vector2, sleeve: Color):
	var v := hand - sh
	var d: float = clamp(v.length(), 4.0, ARM_UPPER + ARM_LOWER - 0.5)
	var dir := v.normalized()
	var a := (ARM_UPPER * ARM_UPPER - ARM_LOWER * ARM_LOWER + d * d) / (2.0 * d)
	var h := sqrt(max(ARM_UPPER * ARM_UPPER - a * a, 0.0))
	var perp := Vector2(-dir.y, dir.x)
	var e1 := sh + dir * a + perp * h
	var e2 := sh + dir * a - perp * h
	# the elbow bends down and away from the body
	var out := 1.0 if sh.x > 0.0 else -1.0
	var elbow := e1 if (e1.y + e1.x * out * 0.8) > (e2.y + e2.x * out * 0.8) else e2
	_stroke(n, sh, elbow, INK, 12.0)
	_stroke(n, elbow, hand, INK, 11.0)
	_stroke(n, sh, elbow, sleeve, 6.0)
	_stroke(n, elbow, hand, sleeve, 5.0)
	# glove with a cuff line
	_ink_disc(n, hand, 7.0, GLOVE, 2.6)


func _draw_head():
	var c := Vector2(2.0, -87.0)
	var r := 22.0
	# ear, face
	_ink_disc(self, c + Vector2(-16, 5), 6.0, SKIN_SHADE, 2.6)
	_ink_disc(self, c, r, SKIN, 3.5)
	# hard hat: dome, brim, ridge, highlight
	var dome := PackedVector2Array()
	for i in 25:
		var a := PI + PI * i / 24.0
		dome.append(c + Vector2(cos(a) * (r + 1.5), sin(a) * (r + 2.0) + 1.0))
	_ink_poly(self, dome, HAT, 3.5)
	draw_arc(c + Vector2(0, 1), r - 5.0, PI + 0.5, PI + 1.25, 8, HAT_LIGHT, 3.0, true)
	ArtDraw.ink_rect(self, Rect2(c.x - 4, c.y - r - 6, 9, 9), HAT_SHADE, 2.4, 3.0)
	ArtDraw.ink_rect(self, Rect2(c.x - r - 4, c.y - 3, 2.0 * r + 15, 7.0), HAT_SHADE, 2.6, 3.0)
	_draw_face(c)


func _draw_face(c: Vector2):
	# he faces right: the features sit a little right of the head centre
	var fx := c.x + 5.0
	var le := Vector2(fx - 8.0, c.y + 9.0)
	var re := Vector2(fx + 8.0, c.y + 9.0)
	var mouth := Vector2(fx + 1.0, c.y + 17.0)
	match mood:
		"normal":
			if _blink > 0.0:
				draw_line(le + Vector2(-4, 0), le + Vector2(4, 0), INK, 2.6, true)
				draw_line(re + Vector2(-4, 0), re + Vector2(4, 0), INK, 2.6, true)
			else:
				for e in [le, re]:
					_disc(self, e, 4.0, INK)
					_disc(self, e + Vector2(1.3, -1.4), 1.4, Color.WHITE)
			draw_arc(mouth + Vector2(0, -4), 6.5, 0.4, PI - 0.4, 12, INK, 2.6, true)
		"stress":
			# big worried eyes, small pupils, furrowed brows, gritted teeth, sweat
			for e in [le, re]:
				_ink_disc(self, e, 6.6, Color.WHITE, 1.8)
				_disc(self, e + Vector2(1.6 + 0.8 * _strength, 0.4), 2.1, INK)
			draw_line(le + Vector2(-7, -10), le + Vector2(6, -6), INK, 3.2, true)
			draw_line(re + Vector2(7, -10), re + Vector2(-6, -6), INK, 3.2, true)
			var mr := Rect2(mouth.x - 8, mouth.y - 5, 16, 9)
			ArtDraw.ink_rect(self, mr, Color.WHITE, 2.0, 3.0)
			draw_line(Vector2(mr.position.x + 5.5, mr.position.y + 1), Vector2(mr.position.x + 5.5, mr.end.y - 1), INK, 1.4, true)
			draw_line(Vector2(mr.position.x + 10.5, mr.position.y + 1), Vector2(mr.position.x + 10.5, mr.end.y - 1), INK, 1.4, true)
			draw_line(Vector2(mr.position.x + 1, mr.position.y + 4.5), Vector2(mr.end.x - 1, mr.position.y + 4.5), INK, 1.4, true)
			# sweat drops flying off the head
			var k := fmod(_t * 2.4, 1.0)
			_drop(Vector2(c.x - 24 - 6 * k, c.y - 8 + 22 * k), 1.0 - k * 0.6)
			_drop(Vector2(c.x + 29, c.y - 14 + 18 * fmod(_t * 2.4 + 0.5, 1.0)), 0.8)
		"throw":
			# eyes squeezed shut (> <), mouth open: "hup!"
			draw_polyline(PackedVector2Array([le + Vector2(-4, -4), le + Vector2(3, 0), le + Vector2(-4, 4)]), INK, 2.6, true)
			draw_polyline(PackedVector2Array([re + Vector2(4, -4), re + Vector2(-3, 0), re + Vector2(4, 4)]), INK, 2.6, true)
			_ink_disc(self, mouth + Vector2(0, -1), 5.5, MOUTH, 2.2)
		"happy":
			# closed smiling eyes (^ ^), big open smile, rosy cheeks
			for e in [le, re]:
				draw_arc(e + Vector2(0, 3), 5.0, PI + 0.25, TAU - 0.25, 12, INK, 2.8, true)
			_disc(self, le + Vector2(-5, 8), 3.6, Color(CHEEK, 0.85))
			_disc(self, re + Vector2(5, 8), 3.6, Color(CHEEK, 0.85))
			var smile := PackedVector2Array()
			for i in 13:
				var a := PI * i / 12.0
				smile.append(mouth + Vector2(cos(a) * 8.5, sin(a) * 8.0 - 4.0))
			_ink_poly(self, smile, MOUTH, 2.2)
			_disc(self, mouth + Vector2(0, 1.0), 2.6, Color("#FF8A8A"))
		"sad":
			# droopy brows, eyes looking down, a tear, small frown
			for e in [le, re]:
				_disc(self, e + Vector2(0, 1), 3.8, INK)
				_disc(self, e + Vector2(1.0, -0.4), 1.3, Color.WHITE)
			draw_line(le + Vector2(-6, -5), le + Vector2(5, -10), INK, 2.8, true)
			draw_line(re + Vector2(6, -5), re + Vector2(-5, -10), INK, 2.8, true)
			draw_arc(mouth + Vector2(0, 5), 6.0, PI + 0.4, TAU - 0.4, 12, INK, 2.6, true)
			var k2 := fmod(_t * 1.1, 1.0)
			_drop(re + Vector2(5, 6 + 14 * k2), 1.0 - k2 * 0.5)


## A teardrop (sweat / tear).
func _drop(p: Vector2, a: float):
	var tip := PackedVector2Array([p + Vector2(0, -6.5), p + Vector2(3.4, 0), p + Vector2(-3.4, 0)])
	_fill(self, tip, Color(INK, a))
	_disc(self, p + Vector2(0, 1.2), 3.8, Color(INK, a))
	_disc(self, p + Vector2(0, 1.2), 2.3, Color(SWEAT, a))
