class_name Worker
extends Node2D
## Freddy, the dock worker. Stands on the conveyor next to the loading spot and reacts:
##   stressed - while the player pulls the cargo back (about to throw)
##   happy    - the cargo landed in the truck
##   sad      - the cargo missed / broke / went the wrong way
##   normal   - otherwise (blinks, breathes)
## Pure decoration: no physics, no effect on levels. Drawn in code (navy outline, flat colours).

const INK := ArtPalette.INK
const SKIN := Color("#F6C9A0")
const SKIN_SHADE := Color("#E3A97C")
const HAT := ArtPalette.MINT
const HAT_SHADE := Color("#2BB07A")
const VEST := ArtPalette.CORAL
const VEST_SHADE := Color("#B83F1F")
const SHIRT := Color("#5C7BA6")
const PANTS := Color("#3A4F73")
const BOOT := Color("#4A3A33")
const REFLECT := Color("#F2F6FA")
const CHEEK := Color("#FF9AA2")
const SWEAT := Color("#8FD0F5")

const MOOD_HOLD := 1.4  # s a happy / sad face stays after a cargo resolves

## The worker's name, in case a screen ever wants to show it.
const WORKER_NAME := "Freddy"

var game: Game
var mood := "normal"  # normal | stress | happy | sad
var _hold_mood := ""
var _hold := 0.0
var _t := 0.0
var _blink := 0.0
var _next_blink := 2.0
var _strength := 0.0  # 0..1 how far the cargo is pulled back


func setup(g: Game):
	game = g
	z_index = 2  # in front of the belt, so his boots stand on it
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	position = Vector2(112, Game.DOCK_TOP + 2)
	game.cargo_resolved.connect(_on_cargo_resolved)


func _on_cargo_resolved(_kind: String, ok: bool, _reason: String):
	_hold_mood = "happy" if ok else "sad"
	_hold = MOOD_HOLD


func _process(delta: float):
	_t += delta
	_hold = max(0.0, _hold - delta)
	var aiming: bool = game != null and game.aiming and game.pull.length() >= 6.0
	_strength = clamp(game.pull.length() / Game.MAX_PULL, 0.0, 1.0) if aiming else 0.0
	var m := "normal"
	if aiming:
		m = "stress"
	elif _hold > 0.0:
		m = _hold_mood
	mood = m
	# blink every few seconds (normal face only)
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.14
		_next_blink = randf_range(2.0, 4.5)
	_blink = max(0.0, _blink - delta)
	queue_redraw()


func _draw():
	var bob := 0.0
	var lean := 0.0
	var shake := 0.0
	match mood:
		"normal":
			bob = sin(_t * 2.2) * 1.2
		"stress":
			lean = -0.10 - 0.12 * _strength  # leans back, winding up
			shake = sin(_t * 55.0) * (0.8 + 1.8 * _strength)
		"happy":
			bob = -abs(sin(_t * 9.0)) * 9.0  # little hops
		"sad":
			bob = 3.0 + sin(_t * 1.6) * 0.8
			lean = 0.05
	draw_set_transform(Vector2(shake, 0), 0.0, Vector2.ONE)
	_draw_legs()
	# upper body: pivots at the hips so he can lean back
	draw_set_transform(Vector2(shake, bob), lean, Vector2.ONE)
	_draw_back_arm()
	_draw_torso()
	_draw_head()
	_draw_front_arm()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- body parts
func _draw_legs():
	var spread := 3.0 if mood == "stress" else 0.0
	for s in [-1, 1]:
		var x: float = s * (8.0 + spread) - 6.0
		ArtDraw.ink_rect(self, Rect2(x, -26, 12, 22), PANTS, 3.0)
		# boot
		ArtDraw.ink_rect(self, Rect2(x - 1, -8, 17, 9), BOOT, 3.0, 3.0)


func _draw_torso():
	var r := Rect2(-18, -64, 36, 42)
	ArtDraw.ink_rect(self, r, SHIRT, 4.0, 6.0)
	# hi-vis vest: two panels with a gap for the shirt in the middle
	var left := PackedVector2Array([Vector2(-18, -64), Vector2(-5, -64), Vector2(-3, -22), Vector2(-18, -22)])
	var right := PackedVector2Array([Vector2(18, -64), Vector2(5, -64), Vector2(3, -22), Vector2(18, -22)])
	ArtDraw.ink_poly(self, left, VEST, 3.5)
	ArtDraw.ink_poly(self, right, VEST, 3.5)
	# reflective stripe + belt
	draw_rect(Rect2(-14, -44, 11, 5), REFLECT)
	draw_rect(Rect2(3, -44, 11, 5), REFLECT)
	draw_rect(Rect2(-14, -31, 11, 3), VEST_SHADE)
	draw_rect(Rect2(3, -31, 11, 3), VEST_SHADE)
	# little name tag on the chest
	ArtDraw.ink_rect(self, Rect2(4, -58, 10, 7), REFLECT, 1.6)


func _arm_points(front: bool) -> Array:
	# returns [shoulder, hand]
	var sh := Vector2(12.0, -58.0) if front else Vector2(-12.0, -58.0)
	var hand := Vector2.ZERO
	match mood:
		"normal":
			hand = sh + Vector2(2.0 if front else -2.0, 28.0 + sin(_t * 2.2) * 1.5)
		"stress":
			# winding up: hands pulled back behind the head, like holding a box to throw
			var k := 0.5 + 0.5 * _strength
			if front:
				hand = sh + Vector2(-30.0 * k - 4.0, -18.0 - 14.0 * k)
			else:
				hand = sh + Vector2(-26.0 * k - 6.0, -8.0 - 14.0 * k)
		"happy":
			var w := sin(_t * 18.0) * 4.0
			hand = sh + Vector2((14.0 if front else -14.0) + w, -26.0 + w)
		"sad":
			hand = sh + Vector2(1.0 if front else -1.0, 27.0)
	return [sh, hand]


func _draw_back_arm():
	_draw_arm(false)


func _draw_front_arm():
	_draw_arm(true)


func _draw_arm(front: bool):
	var pts := _arm_points(front)
	var sh: Vector2 = pts[0]
	var hand: Vector2 = pts[1]
	ArtDraw.ink_line(self, sh, hand, VEST if front else SHIRT, 11.0, 3.0)
	# glove
	ArtDraw.ink_circle(self, hand, 6.5, Color("#F2F0EA"), 3.0)


func _draw_head():
	var c := Vector2(2.0, -86.0)
	var r := 21.0
	# ear (behind), face
	ArtDraw.ink_circle(self, c + Vector2(-15, 4), 6.0, SKIN_SHADE, 3.0)
	ArtDraw.ink_circle(self, c, r, SKIN, 4.5)
	# hard hat: dome + brim
	var dome := PackedVector2Array()
	for i in range(0, 13):
		var a := PI + PI * i / 12.0
		dome.append(c + Vector2(cos(a) * (r + 1.5), sin(a) * (r + 1.0) + 2.0))
	ArtDraw.ink_poly(self, dome, HAT, 4.0)
	draw_rect(Rect2(c.x - 14, c.y - r - 4, 22, 5), Color("#A8F2D0"))  # highlight
	ArtDraw.ink_rect(self, Rect2(c.x - r - 4, c.y - 3, 2.0 * r + 14, 6.0), HAT_SHADE, 3.0)  # brim
	ArtDraw.ink_rect(self, Rect2(c.x - 3, c.y - r - 7, 9, 8), HAT_SHADE, 2.6)  # top ridge
	_draw_face(c)


func _draw_face(c: Vector2):
	var ex := 8.0   # eye offset from the face centre (he faces right: face is nudged to the right)
	var ey := 7.0
	var fx := c.x + 5.0
	var le := Vector2(fx - ex, c.y + ey)
	var re := Vector2(fx + ex, c.y + ey)
	var mouth := Vector2(fx + 1.0, c.y + 16.0)
	match mood:
		"normal":
			if _blink > 0.0:
				draw_line(le + Vector2(-4, 0), le + Vector2(4, 0), INK, 3.0)
				draw_line(re + Vector2(-4, 0), re + Vector2(4, 0), INK, 3.0)
			else:
				for e in [le, re]:
					draw_circle(e, 4.2, INK)
					draw_circle(e + Vector2(1.2, -1.4), 1.4, Color.WHITE)
			draw_arc(mouth + Vector2(0, -4), 6.5, 0.35, PI - 0.35, 10, INK, 3.0)
		"stress":
			# big worried eyes, small pupils, furrowed brows, gritted teeth, sweat
			for e in [le, re]:
				draw_circle(e, 6.8, INK)
				draw_circle(e, 5.0, Color.WHITE)
				draw_circle(e + Vector2(1.6 + 0.8 * _strength, 0.4), 2.1, INK)
			draw_line(le + Vector2(-7, -9), le + Vector2(6, -5), INK, 3.6)
			draw_line(re + Vector2(7, -9), re + Vector2(-6, -5), INK, 3.6)
			var mr := Rect2(mouth.x - 8, mouth.y - 5, 16, 9)
			ArtDraw.ink_rect(self, mr, Color.WHITE, 2.4)
			draw_line(Vector2(mr.position.x + 5.5, mr.position.y), Vector2(mr.position.x + 5.5, mr.end.y), INK, 1.6)
			draw_line(Vector2(mr.position.x + 10.5, mr.position.y), Vector2(mr.position.x + 10.5, mr.end.y), INK, 1.6)
			draw_line(Vector2(mr.position.x, mr.position.y + 4.5), Vector2(mr.end.x, mr.position.y + 4.5), INK, 1.6)
			# sweat drops flying off the head
			var k := fmod(_t * 2.4, 1.0)
			_drop(Vector2(c.x - 22 - 6 * k, c.y - 8 + 22 * k), 1.0 - k * 0.6)
			_drop(Vector2(c.x + 27, c.y - 14 + 18 * fmod(_t * 2.4 + 0.5, 1.0)), 0.8)
		"happy":
			# closed smiling eyes (^ ^), big open smile, rosy cheeks
			for e in [le, re]:
				draw_arc(e + Vector2(0, 3), 5.0, PI + 0.25, TAU - 0.25, 10, INK, 3.2)
			draw_circle(le + Vector2(-5, 8), 4.0, Color(CHEEK, 0.85))
			draw_circle(re + Vector2(5, 8), 4.0, Color(CHEEK, 0.85))
			var smile := PackedVector2Array()
			for i in range(0, 11):
				var a := PI * i / 10.0
				smile.append(mouth + Vector2(cos(a) * 8.5, sin(a) * 8.0 - 4.0))
			ArtDraw.ink_poly(self, smile, Color("#7A2E3A"), 2.4)
			draw_circle(mouth + Vector2(0, 1.5), 3.2, Color("#FF8A8A"))
		"sad":
			# droopy brows, eyes looking down, a tear, small frown
			for e in [le, re]:
				draw_circle(e + Vector2(0, 1), 4.0, INK)
				draw_circle(e + Vector2(1.0, -0.4), 1.3, Color.WHITE)
			draw_line(le + Vector2(-6, -4), le + Vector2(5, -9), INK, 3.2)
			draw_line(re + Vector2(6, -4), re + Vector2(-5, -9), INK, 3.2)
			draw_arc(mouth + Vector2(0, 5), 6.0, PI + 0.4, TAU - 0.4, 10, INK, 3.0)
			var k2 := fmod(_t * 1.1, 1.0)
			_drop(re + Vector2(5, 6 + 14 * k2), 1.0 - k2 * 0.5, SWEAT)


## A teardrop (sweat / tear).
func _drop(p: Vector2, a: float, col: Color = SWEAT):
	var pts := PackedVector2Array([p + Vector2(0, -6), p + Vector2(4.2, 1), p + Vector2(0, 5), p + Vector2(-4.2, 1)])
	draw_colored_polygon(pts, Color(INK, a))
	draw_circle(p + Vector2(0, 1.2), 3.6, Color(INK, a))
	draw_circle(p + Vector2(0, 1.2), 2.2, Color(col, a))
