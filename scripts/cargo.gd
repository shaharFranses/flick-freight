class_name Cargo
extends RigidBody2D
## One piece of cargo. Sits frozen on the conveyor, gets launched, then reports
## once it has come to rest (delivered or not), broken, or left the screen.

signal resolved(cargo: Cargo, delivered: bool, reason: String)

const TYPES = {
	"box": {"tex": "res://art/v2/cargo/box.png", "size": Vector2(60, 60), "mass": 1.0,
		"bounce": 0.08, "friction": 1.0, "power": 1.0, "snd": "hit_wood", "name": "BOX"},
	"crate": {"tex": "res://art/v2/cargo/crate.png", "size": Vector2(62, 62), "mass": 2.4,
		"bounce": 0.04, "friction": 1.0, "power": 0.84, "snd": "hit_metal", "name": "HEAVY CRATE"},
	"barrel": {"tex": "res://art/v2/cargo/barrel.png", "size": Vector2(46, 64), "mass": 1.4,
		"bounce": 0.05, "friction": 0.8, "power": 0.95, "snd": "hit_metal", "name": "BARREL"},
	"fragile": {"tex": "res://art/v2/cargo/fragile.png", "size": Vector2(58, 58), "mass": 1.0,
		"bounce": 0.05, "friction": 1.0, "power": 1.0, "snd": "hit_wood_light", "name": "FRAGILE"},
	# ---- expansion types (docs/EXPANSION_PLAN.md)
	"ice": {"tex": "res://art/v2/cargo/ice.png", "size": Vector2(58, 58), "mass": 1.0,
		"bounce": 0.02, "friction": 0.02, "power": 1.0, "snd": "hit_wood_light", "name": "ICE BLOCK"},
	"tire": {"tex": "res://art/v2/cargo/tire.png", "size": Vector2(56, 56), "mass": 0.8,
		"bounce": 0.6, "friction": 0.9, "power": 1.0, "snd": "boing", "name": "TIRE", "round": true},
	"plank": {"tex": "res://art/v2/cargo/plank.png", "size": Vector2(150, 24), "mass": 1.5,
		"bounce": 0.04, "friction": 1.0, "power": 0.95, "snd": "hit_wood", "name": "PLANK",
		"spin": 2.4, "flat": 20.0},
	"canister": {"tex": "res://art/v2/cargo/canister.png", "size": Vector2(44, 58), "mass": 1.2,
		"bounce": 0.05, "friction": 0.9, "power": 1.0, "snd": "hit_metal", "name": "GAS CAN",
		"pop_speed": 950.0, "pop_force": 520.0},
}

const SETTLE_SPEED := 14.0
const SETTLE_TIME := 0.3
const MAX_AIR_TIME := 7.0
const FRAGILE_HITS := 3  # fragile cargo breaks on this many bumps (level key "fragile_hits")
const HIT_SPEED := 120.0  # a contact faster than this counts as a bump; settling doesn't
const CAB_REST := 0.25  # s resting on the cab before it's a miss
const CAB_MAX := 1.0  # s on the cab at most (sliding/rocking on the hood), then a miss
const HIT_GAP := 0.15  # s; one bump can make several contacts, count it once

var kind := "box"
var info: Dictionary
var flying := false
var done := false
var touched_wall := false
var touched_pad := false
var wind := 0.0
var _settle := 0.0
var _air := 0.0
var _prev_vel := Vector2.ZERO
var _sound_cd := 0.0
var hits := 0  # fragile: bumps so far, shown as cracks
var _hit_cd := 0.0
var cracks: Node2D
var _through_dock := false
var _cab_time := 0.0
var _off_cab := 0.0
var sprite: Sprite2D
var game  # Game (untyped to avoid a cyclic class reference)


func setup(k: String, g):
	kind = k
	game = g
	info = TYPES[k]
	if k == "plank" and g and g.level.has("plank"):
		# M13: per-level plank length / spin
		info = info.duplicate()
		info.size = Vector2(g.level.plank.get("length", info.size.x), info.size.y)
		info.spin = g.level.plank.get("spin", info.spin)
	if k == "canister" and g and g.level.has("canister"):
		# M15: per-level pop threshold / strength
		info = info.duplicate()
		info.pop_speed = g.level.canister.get("pop_speed", info.pop_speed)
		info.pop_force = g.level.canister.get("pop_force", info.pop_force)
	mass = info.mass
	gravity_scale = 1.0
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp = 1.2
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var pm = PhysicsMaterial.new()
	pm.bounce = info.bounce
	pm.friction = info.friction
	physics_material_override = pm
	var cs = CollisionShape2D.new()
	if info.get("round", false):
		var circle = CircleShape2D.new()
		circle.radius = info.size.x * 0.5
		cs.shape = circle
	else:
		var rs = RectangleShape2D.new()
		rs.size = info.size
		cs.shape = rs
	add_child(cs)
	sprite = Sprite2D.new()
	var tex: Texture2D = load(info.tex)
	sprite.texture = tex
	sprite.scale = info.size / tex.get_size()
	add_child(sprite)
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_body_entered)
	add_to_group("cargo")


func half_height() -> float:
	return info.size.y * 0.5


func power_mult() -> float:
	return info.power


func launch(vel: Vector2, wind_accel: float):
	wind = wind_accel
	if game and game.dock_body:
		# a throw never scrapes the deck it was resting on (low throws at a pad keep their
		# power); the dock is ignored until the cargo has cleared its edge
		add_collision_exception_with(game.dock_body)
		_through_dock = true
	freeze = false
	flying = true
	linear_velocity = vel
	angular_velocity = clamp(vel.x * 0.004, -3.0, 3.0)
	if info.has("spin"):
		# M13: fixed, readable spin (no damping in the air)
		angular_velocity = info.spin
		angular_damp = 0.0
	constant_force = Vector2(wind * mass, 0)


## M8: bounce pad hit. Reflect the velocity across the pad's normal with `power` as the
## restitution (>1 = boost). A pad is not a wall: it never breaks fragile cargo.
func bounce_off(n: Vector2, power: float) -> bool:
	var vn = linear_velocity.dot(n)
	if not flying or done or vn >= 0.0:
		return false
	linear_velocity -= (1.0 + power) * vn * n
	touched_pad = true
	return true


func _physics_process(delta: float):
	if not flying or done:
		return
	_air += delta
	_sound_cd = max(0.0, _sound_cd - delta)
	_hit_cd = max(0.0, _hit_cd - delta)
	if _through_dock and global_position.x - info.size.length() * 0.5 > Game.DOCK_RIGHT:
		remove_collision_exception_with(game.dock_body)
		_through_dock = false
	_prev_vel = linear_velocity
	# off-screen
	if global_position.y > 820 or global_position.x > 1420 or global_position.x < -160:
		_finish(false, "lost")
		return
	if _air > MAX_AIR_TIME:
		_finish_in_truck("timeout")
		return
	# resting?
	# (speed is measured relative to the truck when riding in it, so moving trucks still settle)
	var rel = linear_velocity - game.carrier_velocity(self)
	# on the driver's cab: it may still bounce into the bed, but if it stays up there it's
	# a miss quickly (never wait for the full settle/timeout)
	if _touching_cab():
		_off_cab = 0.0
		_cab_time += delta
		if _cab_time > CAB_MAX or (_cab_time > CAB_REST and rel.length() < 60.0):
			_finish(false, "cab")
			return
	elif _cab_time > 0.0:
		# short hops along the roof/hood keep the clock running; only a real escape resets it
		_off_cab += delta
		_cab_time += delta
		if _off_cab > 0.3:
			_cab_time = 0.0
		elif _cab_time > CAB_MAX:
			_finish(false, "cab")
			return
	if _air > 0.25 and rel.length() < SETTLE_SPEED and abs(angular_velocity) < 0.6:
		_settle += delta
		if _settle >= SETTLE_TIME:
			_finish_in_truck("settled")
	else:
		_settle = 0.0


func _on_body_entered(body: Node):
	if not flying or done:
		return
	# wind only pushes while airborne; it shouldn't shove cargo that has landed
	constant_force = Vector2.ZERO
	var impact = _prev_vel.length()
	if _sound_cd <= 0.0 and impact > 60:
		_sound_cd = 0.12
		var vol = clamp(lerp(-18.0, 0.0, impact / 900.0), -18.0, 0.0)
		Sfx.play(info.snd, vol, randf_range(0.92, 1.08))
		if impact > 450 and game:
			game.on_heavy_impact(global_position, impact)
	if info.has("pop_speed") and game and game.verbose:
		print("  canister impact %d (pops above %d)" % [impact, info.pop_speed])
	if info.has("pop_speed") and impact > info.pop_speed and _group_of(body) != "":
		# M15: hard landing, the canister pops and shoves its neighbours
		_finish(false, "popped")
		return
	if info.has("spin"):
		angular_damp = 6.0  # M13: stop spinning soon after touching down, so a flat landing stays flat
	var group = _group_of(body)
	if group == "truck_wall":
		touched_wall = true
		if impact > 120:
			Sfx.play("rim", -6.0, randf_range(0.95, 1.1))
	if kind == "fragile" and impact > HIT_SPEED and _hit_cd <= 0.0:
		# every real bump cracks it; the last one breaks it. Count is drawn on the box.
		_hit_cd = HIT_GAP
		hits += 1
		if hits >= max_hits():
			_finish(false, "broken")
			return
		_crack()
	if group == "ground":
		# landed on the road: no way into the truck from here
		_finish(false, "road")
	elif group == "truck_cab" and impact > 60:
		Sfx.play("rim", -4.0, 0.9)


func _touching_cab() -> bool:
	for b in get_colliding_bodies():
		if b.is_in_group("truck_cab"):
			return true
	return false


func max_hits() -> int:
	return game.level.get("fragile_hits", FRAGILE_HITS) if game else FRAGILE_HITS


func _crack():
	Sfx.play("break", -14.0, 1.6)
	if game:
		game.popup.emit("CRACK! %d/%d" % [hits, max_hits()], global_position + Vector2(0, -46), Color("#FFD34E"), 30)
	if cracks == null:
		cracks = Node2D.new()
		cracks.draw.connect(_draw_cracks)
		add_child(cracks)
	cracks.queue_redraw()


## Dark zig-zag cracks across the box, one per bump.
func _draw_cracks():
	var paths = [
		[Vector2(-26, -20), Vector2(-10, -8), Vector2(-14, 4), Vector2(4, 12), Vector2(2, 26)],
		[Vector2(26, -24), Vector2(12, -12), Vector2(16, 0), Vector2(-2, 6), Vector2(-24, 18)],
		[Vector2(-4, -27), Vector2(2, -14), Vector2(-6, -4), Vector2(8, 4), Vector2(26, 10)],
	]
	for i in min(hits, paths.size()):
		var pts = PackedVector2Array(paths[i])
		cracks.draw_polyline(pts, Color(0.106, 0.165, 0.255, 0.95), 5.0)
		cracks.draw_polyline(pts, Color(1, 1, 1, 0.55), 1.5)


## Knocked loose again after delivery (M15 pop): fly and resolve once more.
func relaunch():
	freeze = false
	done = false
	flying = true
	_air = 0.0
	_settle = 0.0


func _finish_in_truck(reason: String):
	var inside = game.truck_contains(self)
	if inside and info.has("flat") and tilt_deg() > info.flat:
		_finish(false, "tilted")  # M13: long cargo only counts lying (mostly) flat
		return
	_finish(inside, reason)


## Angle from lying flat, in degrees (0 = flat either way up).
func tilt_deg() -> float:
	var a = fposmod(rotation, PI)
	return rad_to_deg(min(a, PI - a))


## Top edge of the (rotated) cargo in world space.
func top_y() -> float:
	var hs = info.size * 0.5
	var ext = abs(hs.x * sin(rotation)) + abs(hs.y * cos(rotation))
	if info.get("round", false):
		ext = hs.x
	return global_position.y - ext


func _group_of(body: Node) -> String:
	for g in ["ground", "dock", "block", "truck_wall", "truck_cab", "truck_floor", "cargo"]:
		if body.is_in_group(g):
			return g
	return ""


func _finish(delivered: bool, reason: String):
	if done:
		return
	done = true
	flying = false
	constant_force = Vector2.ZERO
	resolved.emit(self, delivered, reason)


func fade_out(delay := 0.6):
	collision_layer = 0
	collision_mask = 1  # keep falling onto the road, but nothing collides with it
	var tw = create_tween()
	tw.tween_interval(delay)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
