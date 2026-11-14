class_name Game
extends Node2D
## One level: builds the scene (sky, road, dock, obstacles, truck), runs the
## cargo queue, handles slingshot aiming and decides the result.

signal progress_changed(delivered: int, remaining: int)
signal queue_changed(types: Array)
signal popup(text: String, pos: Vector2, color: Color, size: int)
signal first_throw
signal say(text: String)  # Freddy's speech bubble (a cargo kind he has not handled before)
signal finished(stars: int, delivered: int, total: int)
signal cargo_resolved(kind: String, delivered: bool, reason: String)  # for the QA bot

const ROAD_Y := 625.0
const DOCK_TOP := 430.0
const DOCK_RIGHT := 266.0  # flush with the cargo's front edge: low throws don't scrape a lip
const BELT_RIGHT := 189.0
const FLICK_X := 235.0
## Freddy's step: the dock is cut lower under the loading spot so he stands below the cargo
## and holds it up at belt height. Picture only: the dock's collision box is unchanged.
const STEP_LEFT := 192.0
const STEP_Y := DOCK_TOP + 115.0
const MAX_PULL := 170.0
const POWER := 6.6
const GRAVITY := 1200.0
const TILE := 63.0  # Kenney 70px tiles at 0.9
const NEXT_DELAY := 0.65
## Delivered cargo is not glued to the truck: it stays physical, so stacks can shift or
## topple, and cargo that falls out stops counting.
const FALL_OUT_TIME := 0.25  # s outside the bed before a delivered cargo counts as fallen out
const END_SETTLE := 1.2  # s to let stacks settle before the level is scored

const C_GOOD = Color("#3DDC97")
const C_GOLD = Color("#FFD34E")
const C_BAD = Color("#E4572E")  # coral (guide: miss)

static var verbose := false

var level_index := 0
var level: Dictionary
var queue: Array = []
var current: Cargo = null
var current_ready := false
var slots: Array = []  # truck configs: [level.truck], or level.trucks (several at once)
var trucks: Array = []  # current truck per slot (null while the next one is on its way)
## The first slot's truck: the only one on single-truck levels.
var truck: CargoVehicle:
	get:
		return trucks[0] if not trucks.is_empty() else null
var dock_body: StaticBody2D
var movers: Array = []  # Plan 2 moving obstacles (scripts/mover.gd)
## Extra collision layers cargo only meets while in flight (e.g. M18 bus/train lane).
var flying_mask := 0
const LAYER_FLIGHT := 4  # physics layer 3
var pads: Array = []  # M8: [{node, n, power, squash}]
var truck_count := 0
var delivered := 0
## What Freddy says the first time he picks up each special cargo kind.
const CARGO_NOTES := {
	"crate": "Heavy one!\nPull back harder.",
	"barrel": "A barrel!\nTall and tippy, land it gently.",
	"fragile": "Fragile!\nEvery bump cracks it.",
	"ice": "Ice block!\nThrow it before it melts.",
	"tire": "A tire!\nIt bounces, drop it in softly.",
	"plank": "A plank!\nIt spins as it flies.",
	"girder": "Steel girder!\nHeavy. Pull back harder.",
	"canister": "Gas can!\nLand it softly or it pops.",
	"parcel": "A parcel!\nSmall and light.",
}
var _told := {}  # kinds he has already talked about in this level
var delivered_kinds := {}  # kind -> how many are in a truck right now
var required: Array = []   # kinds that need at least one loaded (Levels.required_kinds)
var _air_kinds := {}       # kind -> how many are in the air
var thrown := 0
## Ice melts in Freddy's hands: seconds left for the ice block he is holding (-1 = not ice).
## It only runs while a throw is possible; a thrown block stops melting.
const MELT_TIME := 7.0
const MELT_WARN := 2.5  # the block blinks for the last seconds
var melt_left := -1.0
var melt_total := MELT_TIME
var melt_ring: Node2D
var _drip_t := 0.0
var in_flight := 0
## Express runs (level.time_limit): the clock starts on the first throw; at zero the vehicle
## has to leave, and whatever was not thrown is left behind.
var time_limit := 0.0
var time_left := 0.0
var clock_running := false
var timed_out := false
var ended := false
var wind := 0.0
var cap := 99

var aiming := false
var press_pos := Vector2.ZERO
var pull := Vector2.ZERO
var rest_pos := Vector2.ZERO

var world: Node2D
var cargo_root: Node2D
var fx_root: Node2D
var aim: Node2D
var beacon: Sprite2D
var worker: Worker
## Pictures of the cargo still to throw, piled on the dock behind Freddy. Same order as
## `queue`: pile[0] is the next one (always on top of the pile).
var pile: Array = []
var clouds: Array[Sprite2D] = []
var flag: Node2D
var wind_fx: Node2D
var streaks: Array = []
var _time := 0.0
## LevelClock (Plan 2 §3.1): physics frames since this level started. A restart builds a new
## Game, so it starts again at 0. Every moving obstacle derives its pose from this alone.
var frame := 0


func setup(index: int):
	level_index = index
	level = Levels.get_level(index)
	queue = Levels.cargo_list(index)
	required = Levels.required_kinds(index)
	time_limit = level.get("time_limit", 0.0)
	time_left = time_limit
	wind = level.get("wind", 0.0)
	cap = level.get("cap", 99)
	slots = level.trucks if level.has("trucks") else [level.truck]
	trucks.resize(slots.size())
	trucks.fill(null)
	world = self
	_build_background()
	_build_road()
	if level.has("water"):
		_build_water()
	_build_dock()
	_build_worker()
	_build_pile()
	_build_blocks()
	if level.has("pads"):
		_build_pads()
	if level.has("height_limit"):
		_build_low_bridge()
	for m in level.get("movers", []):
		var mv: Mover = Movers.make(m.type)
		add_child(mv)
		mv.setup(self, m)
		movers.append(mv)
	if wind != 0.0:
		_build_flag()
		_build_wind_fx()
	cargo_root = Node2D.new()
	add_child(cargo_root)
	fx_root = Node2D.new()
	fx_root.z_index = 20
	add_child(fx_root)
	aim = Node2D.new()
	aim.z_index = 30
	aim.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	aim.draw.connect(_draw_aim)
	add_child(aim)


## Frames until every moving obstacle is back where it started (0 = nothing moves).
## The bot searches release timings over one such cycle.
func motion_period() -> int:
	var p := 0
	for m in movers + live_trucks():
		var q: int = m.period_frames()
		if q > 0:
			p = q if p == 0 else _lcm(p, q)
	for pd in pads:
		if pd.swing != 0.0:
			p = pd.period if p == 0 else _lcm(p, pd.period)
	return min(p, 1200)


static func _lcm(a: int, b: int) -> int:
	var x = a
	var y = b
	while y != 0:
		var t = y
		y = x % y
		x = t
	return a / x * b


## Seconds on the level clock.
func clock_time() -> float:
	return frame / float(Engine.physics_ticks_per_second)


func start():
	for i in slots.size():
		_new_truck(i)
	get_tree().create_timer(0.35, false).timeout.connect(spawn_next)
	queue_changed.emit(remaining_types())
	progress_changed.emit(delivered, queue.size())


# ======================================================================= build
func _static_node() -> Node2D:
	var n = Node2D.new()
	n.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(n)
	return n


func _build_background():
	var w = Levels.world_of(level_index)
	# S1-S3, S6, S7: art/v3/bg/bg_<world>.png (1280x720 or 2x) replaces the Kenney sprite
	# or the whole code backdrop. Missing = today's look.
	var v3bg: Texture2D = ArtAssets.world_background(w.get("name", ""))
	if w.has("backdrop") and v3bg == null:
		var bd = _static_node()
		bd.z_index = -20
		bd.draw.connect(Backdrops.draw.bind(bd, w.backdrop))
		_build_clouds()
		return
	var bg = Sprite2D.new()
	var tex: Texture2D = v3bg
	if tex == null:
		tex = load(w.bg)
	bg.texture = tex
	bg.centered = false
	# New 1280-wide (or 2x) skies sit on the canvas; the Kenney 1024x1024 files keep
	# the original 1.25 scale and (0, -250) offset so a missing v3 file looks identical.
	if tex.get_width() == 1280 or tex.get_width() == 2560:
		var s := 1280.0 / float(tex.get_width())
		bg.scale = Vector2(s, s)
		bg.position = Vector2(0, 0)
	else:
		bg.scale = Vector2(1.25, 1.25)
		bg.position = Vector2(0, -250)
	bg.z_index = -20
	bg.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(bg)
	_build_clouds()


func _build_clouds():
	var ctex: Texture2D = ArtAssets.clouds_texture()
	var cloud_alpha := 1.0 if ctex != null else 0.55
	if ctex == null:
		ctex = load("res://art/v2/bg/clouds.png")
	for i in 2:
		var c = Sprite2D.new()
		c.texture = ctex
		c.centered = false
		c.scale = Vector2(1.3, 0.8)
		c.position = Vector2(i * 1024 * 1.3, -60)
		c.modulate = Color(1, 1, 1, cloud_alpha)
		c.z_index = -19
		c.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(c)
		clouds.append(c)


func _build_road():
	var road = _static_node()
	road.z_index = -10
	road.draw.connect(func():
		road.draw_rect(Rect2(0, ROAD_Y - 16, 1280, 16), ArtPalette.CURB_SHADE)
		road.draw_rect(Rect2(0, ROAD_Y - 16, 1280, 5), ArtPalette.CURB)
		road.draw_rect(Rect2(0, ROAD_Y, 1280, 100), ArtPalette.ROAD)
		road.draw_rect(Rect2(0, ROAD_Y, 1280, 5), ArtPalette.ROAD_EDGE)
		var x = -20.0
		while x < 1300:
			road.draw_rect(Rect2(x, ROAD_Y + 46, 56, 8), ArtPalette.LANE_DASH)
			x += 112.0)
	var ground = StaticBody2D.new()
	ground.add_to_group("ground")
	var pm = PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.05
	ground.physics_material_override = pm
	var cs = CollisionShape2D.new()
	var rs = RectangleShape2D.new()
	rs.size = Vector2(3000, 200)
	cs.shape = rs
	cs.position = Vector2(640, ROAD_Y + 100)
	ground.add_child(cs)
	add_child(ground)


func _tile(parent: Node, file: String, pos: Vector2, z := 0, tex: Texture2D = null) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = tex if tex else load(file)
	s.centered = false
	# v3 63 px tiles are already in design pixels; 2x is 126 px; Kenney 70 px stays at 0.9.
	var tw := float(s.texture.get_width())
	var sc := 1.0
	if tw == TILE * 2:
		sc = 0.5
	elif tw != TILE:
		sc = 0.9
	s.scale = Vector2(sc, sc)
	s.position = pos
	s.z_index = z
	s.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(s)
	return s


const WAREHOUSE_RIGHT := 168.0
const WAREHOUSE_TOP := 196.0
const DOOR = Rect2(14, 282, 140, 148)  # roll-up door the conveyor comes out of


func _build_dock():
	# warehouse wall behind the conveyor (behind the cargo)
	var wh = _static_node()
	wh.z_index = -3
	var wh_tex := ArtAssets.warehouse_texture()
	if wh_tex:
		_place_dock_sprite(wh, wh_tex, Vector2(-10, WAREHOUSE_TOP - 6))
	else:
		wh.draw.connect(_draw_warehouse.bind(wh))
	# dock platform (in front of the cargo's lower edge)
	var dock = _static_node()
	dock.z_index = 1
	var face_tex := ArtAssets.dock_face_texture()
	if face_tex:
		# the PNG is drawn in pieces so the step under the loading spot is cut out of it
		var ts := face_tex.get_size()
		var cut := STEP_LEFT + 10.0
		var drop := STEP_Y - DOCK_TOP
		_place_dock_sprite(dock, face_tex, Vector2(-10, DOCK_TOP), Rect2(0, 0, cut, ts.y))
		_place_dock_sprite(dock, face_tex, Vector2(STEP_LEFT, STEP_Y), Rect2(cut, drop, ts.x - cut, ts.y - drop))
		# the deck lip with its hazard nose moves down onto the step
		_place_dock_sprite(dock, face_tex, Vector2(STEP_LEFT, STEP_Y), Rect2(cut, 0, DOCK_RIGHT + 11.0 - cut, 36))
		var edge = _static_node()
		edge.z_index = 1
		edge.draw.connect(func():
			edge.draw_rect(Rect2(STEP_LEFT - 4, DOCK_TOP, 4, drop + 4), ArtPalette.INK))
	else:
		dock.draw.connect(_draw_dock_face.bind(dock))
	# conveyor belt set into the deck (Kenney industrial belt tiles, or v3 drop-ins)
	var belts = ["ind_049", "ind_050", "ind_051"]
	for i in 3:
		_tile(dock, "res://art/v2/tiles/%s.png" % belts[i], Vector2(i * TILE, DOCK_TOP), 0, ArtAssets.belt_texture(i))
	# beacon that pulses when cargo is ready to throw (on the warehouse roof)
	beacon = _tile(dock, "res://art/v2/tiles/ind_040.png", Vector2(WAREHOUSE_RIGHT - 70, WAREHOUSE_TOP - TILE + 2), 0, ArtAssets.beacon_texture())
	var body = StaticBody2D.new()
	dock_body = body
	body.add_to_group("dock")
	var cs = CollisionShape2D.new()
	var rs = RectangleShape2D.new()
	rs.size = Vector2(DOCK_RIGHT, ROAD_Y - DOCK_TOP)
	cs.shape = rs
	cs.position = Vector2(DOCK_RIGHT * 0.5, (DOCK_TOP + ROAD_Y) * 0.5)
	body.add_child(cs)
	add_child(body)


## The level's cargo is tossed out of the warehouse and piled up on the dock behind Freddy.
## Pictures only (no physics). Stacked last-to-throw first, so the next one is always on top.
func _build_pile():
	var root = _static_node()
	var cols := [150.0, 90.0, 30.0]
	var heights := [0.0, 0.0, 0.0]
	# long cargo (planks) stands on end at the back of the dock, leaning on the warehouse
	# wall; the rest of the pile then keeps to the two columns next to Freddy
	var long_n := 0
	for kind in queue:
		if Cargo.size_of(kind, level).x > 70.0:
			long_n += 1
	if long_n > 0:
		cols = [150.0, 96.0]
		heights = [0.0, 0.0]
	var stood := 0
	pile.resize(queue.size())
	var order := 0
	for i in range(queue.size() - 1, -1, -1):
		var kind: String = queue[i]
		var size: Vector2 = Cargo.size_of(kind, level)
		var pos := Vector2.ZERO
		var lean := 0.0
		if size.x > 70.0:
			# the next plank to throw is the one nearest Freddy
			var slot := long_n - 1 - stood
			stood += 1
			lean = -PI * 0.5 + 0.09
			pos = Vector2(16.0 + 15.0 * slot, DOCK_TOP - size.x * 0.5 + 2.0)
		else:
			var c := 0
			for j in cols.size():
				if heights[j] < heights[c] - 0.5:
					c = j
			pos = Vector2(cols[c], DOCK_TOP - heights[c] - size.y * 0.5)
			heights[c] += size.y
		var pic: Node2D = Cargo.make_picture(kind, size)
		pic.rotation = lean
		pic.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		root.add_child(pic)
		var from := Vector2(-60.0, DOOR.get_center().y)
		pic.position = from
		pile[i] = pic
		var tw = create_tween()
		tw.tween_interval(0.02 + 0.04 * order)
		tw.tween_method(_toss.bind(pic, from, pos), 0.0, 1.0, 0.3)
		order += 1


func _toss(k: float, pic: Node2D, from: Vector2, to: Vector2):
	if is_instance_valid(pic):
		pic.position = from.lerp(to, k) + Vector2(0, -50.0 * sin(k * PI))


func _clear_pile():
	for pic in pile:
		if is_instance_valid(pic):
			pic.queue_free()
	pile.clear()


## Freddy says a line about a special cargo kind: the first time the player ever meets it,
## and always on the level that introduces it. Once per level at most.
func _note_kind(kind: String):
	if not CARGO_NOTES.has(kind) or _told.has(kind):
		return
	_told[kind] = true
	var introduced: bool = level.get("intro", {}).get("icon", "") == kind
	if introduced or not SaveData.get_flag("met_" + kind, false):
		SaveData.set_flag("met_" + kind, true)
		say.emit(CARGO_NOTES[kind])


## The next cargo hops from the pile into Freddy's hands (same 0.5 s as before).
func _carry(k: float, c: Cargo, from: Vector2, hop: float):
	if is_instance_valid(c):
		c.global_position = from.lerp(rest_pos, k) + Vector2(0, -hop * sin(k * PI))


## Freddy, the dock worker (scripts/worker.gd): reacts to aiming, hits and misses.
func _build_worker():
	worker = Worker.new()
	add_child(worker)
	worker.setup(self)


func _place_dock_sprite(parent: Node2D, tex: Texture2D, top_left: Vector2, region := Rect2()):
	var s = Sprite2D.new()
	s.texture = tex
	s.centered = false
	if region.size.x > 0 and region.size.y > 0:
		s.region_enabled = true
		s.region_rect = region
	s.position = top_left
	s.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(s)


func _draw_warehouse(n: Node2D):
	var wall = Color("#7E8FA3")
	var rib = Color("#93A4B7")
	var trim = Color("#4A5568")
	var R = WAREHOUSE_RIGHT
	# corrugated siding
	n.draw_rect(Rect2(-10, WAREHOUSE_TOP, R + 10, DOCK_TOP - WAREHOUSE_TOP), wall)
	var x = 2.0
	while x < R:
		n.draw_rect(Rect2(x, WAREHOUSE_TOP + 14, 5, DOCK_TOP - WAREHOUSE_TOP - 14), rib)
		x += 16.0
	# roof trim + gutter, side edge shadow
	n.draw_rect(Rect2(-10, WAREHOUSE_TOP - 6, R + 22, 20), trim)
	n.draw_rect(Rect2(-10, WAREHOUSE_TOP - 6, R + 22, 5), trim.lightened(0.25))
	n.draw_rect(Rect2(R - 6, WAREHOUSE_TOP + 14, 6, DOCK_TOP - WAREHOUSE_TOP - 14), wall.darkened(0.2))
	# roll-up door: amber frame, dark opening, shutter half-raised
	var d = DOOR
	n.draw_rect(d.grow(8), Color("#F2B134"))
	n.draw_rect(d, Color("#20262F"))
	var shutter_h = 52.0
	n.draw_rect(Rect2(d.position, Vector2(d.size.x, shutter_h)), Color("#AAB4BF"))
	var y = d.position.y + 8
	while y < d.position.y + shutter_h:
		n.draw_line(Vector2(d.position.x, y), Vector2(d.end.x, y), Color("#8C96A1"), 2.0)
		y += 9.0
	n.draw_rect(Rect2(d.position.x, d.position.y + shutter_h - 5, d.size.x, 5), Color("#6B7684"))
	# lamp over the door
	n.draw_rect(Rect2(d.get_center().x - 22, d.position.y - 26, 44, 8), trim)
	n.draw_circle(Vector2(d.get_center().x, d.position.y - 16), 7, Color("#FFE27A"))


func _draw_dock_face(n: Node2D):
	var concrete = Color("#C9CED6")
	var seam = Color("#AEB5BF")
	var lip = Color("#5B6574")
	var top = DOCK_TOP
	var R = DOCK_RIGHT
	var L = STEP_LEFT  # right of this the dock is cut down to STEP_Y (Freddy's step)
	# concrete body
	n.draw_rect(Rect2(-10, top, L + 10, ROAD_Y - top + 4), concrete)
	n.draw_rect(Rect2(L, STEP_Y, R - L, ROAD_Y - STEP_Y + 4), concrete)
	n.draw_rect(Rect2(-10, ROAD_Y - 10, R + 10, 14), seam)  # footing
	for px in [62.0, 126.0, 190.0, 254.0]:
		n.draw_line(Vector2(px, (top if px < L else STEP_Y) + 40), Vector2(px, ROAD_Y - 10), seam, 3.0)
	n.draw_line(Vector2(-10, top + 112), Vector2(L, top + 112), seam, 3.0)
	# steel deck lip on the step, with a hazard nose at the edge
	n.draw_rect(Rect2(BELT_RIGHT, top, L - BELT_RIGHT, 14), lip)
	n.draw_rect(Rect2(L, STEP_Y, R - L, 14), lip)
	n.draw_rect(Rect2(L, STEP_Y, R - L, 3), lip.lightened(0.3))
	var hz = Rect2(R - 56, STEP_Y + 14, 56, 16)
	n.draw_rect(hz, Color("#2E3440"))
	var sx = hz.position.x - 16
	while sx < hz.end.x:
		var poly = PackedVector2Array([Vector2(sx, hz.end.y), Vector2(sx + 16, hz.position.y),
			Vector2(sx + 26, hz.position.y), Vector2(sx + 10, hz.end.y)])
		var clipped = Geometry2D.intersect_polygons(poly, PackedVector2Array([hz.position,
			Vector2(hz.end.x, hz.position.y), hz.end, Vector2(hz.position.x, hz.end.y)]))
		for c in clipped:
			n.draw_colored_polygon(c, Color("#F2B134"))
		sx += 20
	# belt frame under the rollers
	n.draw_rect(Rect2(-10, top + 27, BELT_RIGHT + 10, 13), lip)
	# shadow of the deck lip on the wall
	n.draw_rect(Rect2(-10, top + 40, L + 10, 6), Color(0, 0, 0, 0.08))
	# wall of the step
	n.draw_rect(Rect2(L - 4, top, 4, STEP_Y - top), lip)
	# rubber dock bumper on the face
	n.draw_rect(Rect2(R - 4, top + 128.0, 14, 40), Color("#2E3440"))
	n.draw_rect(Rect2(R + 6, top + 132.0, 4, 32), Color("#454C59"))


func _build_blocks():
	for b in level.get("blocks", []):
		var r = Rect2(b[0], b[1], b[2], b[3])
		var body = StaticBody2D.new()
		body.add_to_group("block")
		var pm = PhysicsMaterial.new()
		pm.bounce = 0.3
		body.physics_material_override = pm
		var cs = CollisionShape2D.new()
		var rs = RectangleShape2D.new()
		rs.size = r.size
		cs.shape = rs
		cs.position = r.get_center()
		body.add_child(cs)
		add_child(body)
		var v = _static_node()
		v.z_index = 1
		v.draw.connect(_draw_girder.bind(v, r))


# ======================================================================= M8 bounce pads
const PAD_W := 120.0
const PAD_H := 30.0


## level.pads: [[x, y, angle_deg, power]]. (x, y) = middle of the spring plate's face,
## angle 0 = facing straight up, +90 = facing right. power = restitution (1 = elastic).
## Rocking pad: [x, y, angle_deg, power, swing_deg, period_frames, phase_frames]: the pad tilts
## `swing_deg` either side of `angle_deg` on the level clock, so the bounce direction changes.
func _build_pads():
	for d in level.pads:
		if d.size() > 4:
			var stand = _static_node()
			stand.z_index = 0
			var c = Vector2(d[0], d[1])
			stand.draw.connect(func():
				ArtDraw.ink_rect(stand, Rect2(c.x - 9, c.y + 16, 18, ROAD_Y - c.y - 16), ArtPalette.STEEL_LIGHT, 3.0)
				ArtDraw.ink_rect(stand, Rect2(c.x - 34, ROAD_Y - 12, 68, 12), ArtPalette.DOCK_STEEL, 3.0))
		var a = Area2D.new()
		a.position = Vector2(d[0], d[1])
		a.rotation = deg_to_rad(d[2])
		a.add_to_group("pad")
		var cs = CollisionShape2D.new()
		var rs = RectangleShape2D.new()
		rs.size = Vector2(PAD_W, PAD_H)
		cs.shape = rs
		cs.position = Vector2(0, PAD_H * 0.5 - 6)  # face sits 6 px into the area
		a.add_child(cs)
		add_child(a)
		var vis = Node2D.new()
		vis.z_index = 1
		vis.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		a.add_child(vis)
		var pd = {"node": a, "vis": vis, "n": Vector2.UP.rotated(a.rotation), "power": float(d[3]), "squash": 0.0,
			"base": a.rotation, "swing": deg_to_rad(d[4]) if d.size() > 4 else 0.0,
			"period": int(d[5]) if d.size() > 5 else 300, "phase": int(d[6]) if d.size() > 6 else 0}
		vis.draw.connect(_draw_pad.bind(pd))
		a.body_entered.connect(_on_pad_body.bind(pd))
		pads.append(pd)


func _on_pad_body(body: Node, pd: Dictionary):
	if body is Cargo and body.bounce_off(pd.n, pd.power):
		pd.squash = 1.0
		Sfx.play("boing", -4.0, randf_range(0.95, 1.1))


## Angle of a pad at clock frame f (a rocking pad tilts on the level clock).
func pad_angle(pd: Dictionary, f: int) -> float:
	if pd.swing == 0.0:
		return pd.base
	return pd.base + pd.swing * sin(TAU * (f + pd.phase) / float(pd.period))


## The pad's face normal at clock frame f.
func pad_normal(pd: Dictionary, f: int) -> Vector2:
	return Vector2.UP.rotated(pad_angle(pd, f))


## Does a cargo centred at p (half extent `half` along the normal) touch the pad's face?
## f = clock frame to test at (-1 = now).
func pad_contact(pd: Dictionary, p: Vector2, half: float, f := -1) -> bool:
	var a: Area2D = pd.node
	var l = (p - a.position).rotated(-(a.rotation if f < 0 else pad_angle(pd, f)))
	return abs(l.x) < PAD_W * 0.5 + half * 0.5 and l.y > -half - 6 and l.y < PAD_H


func _draw_pad(pd: Dictionary):
	var n: Node2D = pd.vis
	var sq = sin(pd.squash * PI) * 10.0
	var w = PAD_W
	# base on the ground
	ArtDraw.ink_rect(n, Rect2(-w * 0.5 - 2, PAD_H - 12, w + 4, 14), ArtPalette.DOCK_STEEL, 2.6)
	if pd.swing != 0.0:  # rocking pad: the pivot it tilts around
		ArtDraw.ink_circle(n, Vector2(0, PAD_H - 5), 11, ArtPalette.GOLD, 3.0)
		n.draw_circle(Vector2(0, PAD_H - 5), 3, ArtPalette.INK)
	# two coil springs (pushed down by `sq` on a hit)
	var top = sq + 6.0
	for sx in [-w * 0.27, w * 0.27]:
		var pts = PackedVector2Array()
		for k in 7:
			pts.append(Vector2(sx + (-12 if k % 2 == 0 else 12), lerp(PAD_H - 10.0, top, k / 6.0)))
		n.draw_polyline(pts, ArtPalette.INK, 9.0)
		n.draw_polyline(pts, ArtPalette.CHROME, 4.0)
	# plate: its face sits at y = 0
	var plate = Rect2(-w * 0.5, top - 14, w, 14)
	ArtDraw.ink_rect(n, plate.grow(2), ArtPalette.CORAL, 3.0)
	n.draw_rect(Rect2(plate.position + Vector2(1, 1), Vector2(w - 2, 3)), ArtPalette.CORAL_HI)
	var x = plate.position.x + 8
	while x < plate.end.x - 14:  # gold chevrons
		n.draw_colored_polygon(PackedVector2Array([Vector2(x, plate.end.y - 2), Vector2(x + 7, plate.position.y + 5),
			Vector2(x + 14, plate.end.y - 2)]), ArtPalette.GOLD)
		x += 22.0


# ======================================================================= M14 low bridge
## The height limit as a real low bridge on the way out (Plan 2, D2). It hangs over the parked
## truck's cab; its underside is at exactly the limit above the load floor. The rule is
## unchanged (cargo settling above the limit is knocked off); after a won level the truck
## drives out underneath it.
func _build_low_bridge():
	var cfg: Dictionary = slots[0]
	var floor_y = ROAD_Y - Truck.FLOOR_T - 18 - Truck.WHEEL_R
	var under = floor_y - level.height_limit
	var park_x = cfg.x
	if cfg.get("vehicle", "truck") == "truck":
		park_x = Truck.fitted_base_x(cfg.x)
	var x0 = park_x + Truck.BED_W * 0.5 + Truck.WALL_T + 12  # just past the bulkhead
	var n = _static_node()
	n.z_index = 4  # in front of the cab: the cab is "under" the bridge
	var style = Levels.world_of(level_index).get("bridge", "stone")
	n.draw.connect(func(): Bridges.draw(n, style, Rect2(x0, under - 64, 1400 - x0, 64), ROAD_Y))


# ======================================================================= M10 harbor water
## level.water: [x0, x1] stretch of road that is open water (ferry levels). Cargo that
## lands there splashes. Physics is the same as the road (it's a miss either way).
func _build_water():
	var n = _static_node()
	n.z_index = -9
	var w = level.water
	n.draw.connect(func():
		n.draw_rect(Rect2(w[0], ROAD_Y - 18, w[1] - w[0], 140), ArtPalette.WATER)
		n.draw_rect(Rect2(w[0], ROAD_Y - 18, w[1] - w[0], 6), ArtPalette.WATER_HI)
		n.draw_rect(Rect2(w[0], ROAD_Y + 62, w[1] - w[0], 60), ArtPalette.WATER_SHADE)
		var x = w[0] + 10.0
		while x < w[1] - 30:
			n.draw_rect(Rect2(x, ROAD_Y + 28, 26, 4), ArtPalette.WATER_HI)
			x += 70.0
		# quay edges
		ArtDraw.ink_rect(n, Rect2(w[0] - 12, ROAD_Y - 18, 12, 122), ArtPalette.CONCRETE, 3.0)
		ArtDraw.ink_rect(n, Rect2(w[1], ROAD_Y - 18, 12, 122), ArtPalette.CONCRETE, 3.0))


func in_water(p: Vector2) -> bool:
	return level.has("water") and p.x > level.water[0] and p.x < level.water[1]


func _draw_girder(n: Node2D, r: Rect2):
	# steel lattice with an inside navy outline and hazard ends: has to read on every backdrop.
	# The outline is inside r, so the drawn edge is the collision edge.
	var dark = ArtPalette.STEEL_SHADE
	ArtDraw.ink_rect(n, r, ArtPalette.STEEL, ArtDraw.PROP)
	var e = ArtDraw.PROP
	var vertical = r.size.y > r.size.x
	if vertical:
		n.draw_rect(Rect2(r.position.x + e, r.position.y + e, 4, r.size.y - 2 * e), ArtPalette.STEEL_LIGHT)
		var y = r.position.y + 10
		var flip = false
		while y < r.end.y - 10:
			var y2 = min(y + r.size.x, r.end.y - 8)
			var a = Vector2(r.position.x + 8, y)
			var b = Vector2(r.end.x - 8, y2)
			if flip:
				a.x = r.end.x - 8
				b.x = r.position.x + 8
			n.draw_line(a, b, dark, 4.0)
			flip = not flip
			y = y2
		_hazard(n, Rect2(r.position.x, r.end.y - 13, r.size.x, 13))  # ends are where cargo clips
		if r.position.y > 0:
			_hazard(n, Rect2(r.position.x, r.position.y, r.size.x, 13))
	else:
		n.draw_rect(Rect2(r.position.x + e, r.position.y + e, r.size.x - 2 * e, 4), ArtPalette.STEEL_LIGHT)
		var x = r.position.x + 10
		var flip = false
		while x < r.end.x - 10:
			var x2 = min(x + r.size.y, r.end.x - 8)
			var a = Vector2(x, r.position.y + 9)
			var b = Vector2(x2, r.end.y - 9)
			if flip:
				a.y = r.end.y - 9
				b.y = r.position.y + 9
			n.draw_line(a, b, dark, 4.0)
			flip = not flip
			x = x2
		_hazard(n, Rect2(r.position.x, r.end.y - 12, r.size.x, 12))


func _hazard(n: Node2D, hz: Rect2):
	ArtDraw.hazard(n, hz, 10.0, 3.0)


func _build_flag():
	flag = Node2D.new()
	flag.position = Vector2(118, WAREHOUSE_TOP - 6)
	flag.z_index = 2
	flag.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	flag.draw.connect(_draw_flag)
	add_child(flag)


func _draw_flag():
	var h = 88.0
	ArtDraw.ink_rect(flag, Rect2(-4, -h, 8, h), ArtPalette.CHROME, 2.0)
	var dir = sign(wind)
	var length = 40.0 + abs(wind) * 0.35
	var pts = PackedVector2Array()
	var pts2 = PackedVector2Array()
	for i in 9:
		var t = i / 8.0
		var wave = sin(_time * (6.0 + abs(wind) * 0.03) - t * 5.0) * 6.0 * t
		pts.append(Vector2(dir * length * t, -h + 2 + wave))
		pts2.append(Vector2(dir * length * t, -h + 32 - 12 * t + wave))
	var poly = pts.duplicate()
	pts2.reverse()
	poly.append_array(pts2)
	var outer = Geometry2D.offset_polygon(poly, 2.6)
	if not outer.is_empty():
		flag.draw_colored_polygon(outer[0], ArtPalette.INK)
	flag.draw_colored_polygon(poly, ArtPalette.CORAL)
	for i in range(1, 3):
		var t = i / 3.0
		var wave = sin(_time * (6.0 + abs(wind) * 0.03) - t * 5.0) * 6.0 * t
		flag.draw_line(Vector2(dir * length * t, -h + 2 + wave), Vector2(dir * length * t, -h + 32 - 12 * t + wave), Color.WHITE, 5.0)
	ArtDraw.ink_circle(flag, Vector2(0, -h), 7, ArtPalette.CHROME, 2.0)


## Air streaks blowing across the whole screen, so the wind reads at a glance.
func _build_wind_fx():
	wind_fx = Node2D.new()
	wind_fx.z_index = 3
	wind_fx.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	wind_fx.draw.connect(_draw_wind_fx)
	add_child(wind_fx)
	var n = int(10 + abs(wind) * 0.07)
	for i in n:
		streaks.append({"x": randf_range(-200, 1480), "y": randf_range(20, ROAD_Y - 30),
			"len": randf_range(50, 150), "speed": randf_range(0.7, 1.3), "a": randf_range(0.18, 0.4)})


func _draw_wind_fx():
	var dir = sign(wind)
	for s in streaks:
		var wave = sin(_time * 3.0 + s.y * 0.05) * 4.0
		var head = Vector2(s.x, s.y + wave)
		var tail = head - Vector2(dir * s.len, 0)
		wind_fx.draw_line(tail, head, Color(1, 1, 1, s.a * 0.5), 3.0)
		wind_fx.draw_line(tail.lerp(head, 0.5), head, Color(1, 1, 1, s.a), 3.0)


# ======================================================================= trucks
func _new_truck(slot: int):
	var cfg: Dictionary = slots[slot]
	var t: CargoVehicle = Vehicles.make(cfg.get("vehicle", "truck"))
	# V0 truck colour is always red. Other vehicles keep their own look index
	# (e.g. courier-bike accents); bed physics are unchanged either way.
	var pal: int = level_index + truck_count
	if cfg.get("vehicle", "truck") == "truck":
		pal = Truck.resolved_palette_index(pal)
	t.setup(cfg, pal, cfg.get("wall", 52))
	t.height_limit = level.get("height_limit", 0.0)
	for ch in cfg.get("accepts", ""):
		t.accepts.append(Levels.LETTER[ch])
	t.position = Vector2(1560, t.floor_y(ROAD_Y))
	if slot > 0:
		t.z_index = -slot  # far trucks behind near ones while driving in
	add_child(t)
	trucks[slot] = t
	truck_count += 1
	t.departed.connect(_on_truck_departed.bind(slot))
	t.arrive()


func _on_truck_departed(slot: int):
	trucks[slot] = null
	if slots[slot].get("once", false):
		# e.g. a train flatcar: it doesn't come back. When nothing is left to throw at, the
		# level is over (cargo not thrown yet counts as missed)
		if live_trucks().is_empty() and not ended:
			queue.clear()
			_clear_pile()
			if current:
				current.queue_free()
				current = null
			_check_end()
		return
	if not ended and work_left() > 0:
		_new_truck(slot)


func live_trucks() -> Array:
	var out: Array = []
	for t in trucks:
		if t != null and is_instance_valid(t):
			out.append(t)
	return out


func truck_of(c: Cargo) -> CargoVehicle:
	for t in live_trucks():
		if holds(t, c) and t.takes(c.kind):
			return t
	return null


## Is the cargo in this vehicle's load zone? Its centre may sit a little outside (up to 30% of
## its width, 20 px at most): a box resting on the bed but leaning on the cab or the rider
## is loaded, not a miss.
func holds(t: CargoVehicle, c: Cargo) -> bool:
	var s: float = min(c.info.size.x * 0.3, 20.0)
	for dx in [0.0, -s, s]:
		if t.contains_point(c.global_position + Vector2(dx, 0)):
			return true
	return false


## Is any part of the cargo over a load zone (it can still tip or slide into the bed)?
func over_bed(c: Cargo) -> bool:
	var hw: float = c.info.size.x * 0.5
	for t in live_trucks():
		for dx in [-hw, 0.0, hw]:
			if t.contains_point(c.global_position + Vector2(dx, 0)):
				return true
	return false


## Landed in a vehicle that doesn't take this kind of cargo.
func wrong_truck(c: Cargo) -> bool:
	for t in live_trucks():
		if holds(t, c) and not t.takes(c.kind):
			return true
	return false


func truck_contains(c: Cargo) -> bool:
	return truck_of(c) != null


func carrier_velocity(c: Cargo) -> Vector2:
	# anything resting on the truck (bed, tailgate top, ...) moves with it
	for t in live_trucks():
		if t.on_vehicle(c.global_position):
			return t.point_velocity(c.global_position)
	return Vector2.ZERO


# ======================================================================= cargo flow
func remaining_types() -> Array:
	var out: Array = []
	if current:
		out.append(current.kind)
	out.append_array(queue)
	return out


func work_left() -> int:
	return queue.size() + (1 if current else 0) + in_flight


func spawn_next():
	if ended or current != null or queue.is_empty():
		return
	var kind: String = queue.pop_front()
	_note_kind(kind)
	var c = Cargo.new()
	c.setup(kind, self)
	cargo_root.add_child(c)
	rest_pos = Vector2(FLICK_X, DOCK_TOP - c.half_height())
	var from := Vector2(-50, rest_pos.y)
	if not pile.is_empty():
		var pic = pile.pop_front()
		if is_instance_valid(pic):
			from = pic.global_position
			pic.queue_free()
	c.global_position = from
	c.reset_physics_interpolation()
	current = c
	current_ready = false
	Sfx.play("conveyor", -8.0)
	var tw = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var hop := 24.0 + 0.1 * from.distance_to(rest_pos)
	tw.tween_method(_carry.bind(c, from, hop), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): current_ready = true)
	melt_left = -1.0
	if kind == "ice":
		melt_total = level.get("melt", MELT_TIME)
		melt_left = melt_total
		_build_melt_ring()
	queue_changed.emit(remaining_types())


func can_aim() -> bool:
	if ended or current == null or not current_ready:
		return false
	for t in live_trucks():
		# one-parcel vehicles (cap 1, e.g. couriers): wait for the parcel in the air to land;
		# a loaded one is about to ride off, so it's not a target
		if t.is_parked() and not (cap == 1 and (t.load_count() >= 1 or in_flight > 0)):
			return true
	return false


func launch_velocity(p: Vector2) -> Vector2:
	return p * POWER * (current.power_mult() if current else 1.0)


func _unhandled_input(event: InputEvent):
	# designer time-scrub (debug builds only): [ and ] move the level clock by half a second
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not movers.is_empty():
		if event.keycode == KEY_BRACKETRIGHT:
			frame += 30
		elif event.keycode == KEY_BRACKETLEFT:
			frame = max(0, frame - 30)
	if ended:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos = make_input_local(event).position
		if event.pressed:
			if can_aim():
				aiming = true
				press_pos = pos
				pull = Vector2.ZERO
				get_viewport().set_input_as_handled()
		elif aiming:
			aiming = false
			get_viewport().set_input_as_handled()
			# use the release point too: fast flicks may deliver few/no motion events
			_update_pull(pos)
			if pull.length() < 22.0 or not can_aim():
				_cancel_aim()
			else:
				_throw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and aiming:
		aiming = false
		_cancel_aim()
	elif event is InputEventMouseMotion and aiming:
		_update_pull(make_input_local(event).position)


func _update_pull(pos: Vector2):
	pull = (press_pos - pos).limit_length(MAX_PULL)
	# never aim backwards into the warehouse
	pull.x = max(pull.x, 0.0)
	if current:
		current.global_position = rest_pos - pull.normalized() * min(pull.length() * 0.16, 24.0)
	aim.queue_redraw()


func _cancel_aim():
	pull = Vector2.ZERO
	if current:
		var tw = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tw.tween_property(current, "global_position", rest_pos, 0.12)
	aim.queue_redraw()


# ======================================================================= melting ice
func _build_melt_ring():
	if melt_ring == null:
		melt_ring = _static_node()
		melt_ring.z_index = 25
		melt_ring.draw.connect(_draw_melt_ring)


## A ring above the ice block Freddy holds: it empties as the block melts.
func _draw_melt_ring():
	if melt_left <= 0.0 or current == null or not current_ready:
		return
	var k: float = clamp(melt_left / melt_total, 0.0, 1.0)
	var c: Vector2 = current.global_position + Vector2(0, -current.half_height() - 30.0)
	var col: Color = ArtPalette.CORAL if melt_left < MELT_WARN else ArtPalette.BLUE
	melt_ring.draw_circle(c, 17.0, ArtPalette.INK)
	melt_ring.draw_circle(c, 13.5, Color.WHITE)
	melt_ring.draw_arc(c, 9.0, -PI * 0.5, -PI * 0.5 + TAU * k, 32, col, 8.0)


func _melt_tick(delta: float):
	if melt_left <= 0.0 or current == null or current.kind != "ice":
		return
	if can_aim():
		melt_left -= delta
	melt_ring.queue_redraw()
	# drips, faster as it runs out; the block blinks for the last seconds
	_drip_t -= delta
	if _drip_t <= 0.0:
		_drip_t = lerp(0.12, 0.5, clamp(melt_left / melt_total, 0.0, 1.0))
		var at: Vector2 = current.global_position + Vector2(randf_range(-20, 20), current.half_height())
		Fx.burst(fx_root, at, Fx.tex(Fx.RING), ArtPalette.WATER_HI, 2, 50.0, 0.5, 0.1, 900.0, 20.0, Vector2.DOWN)
	if melt_left < MELT_WARN:
		current.modulate.a = 0.55 + 0.45 * abs(sin(melt_left * 9.0))
	if melt_left <= 0.0:
		_melted()


## The block melted before it was thrown: it is gone (a miss), the next cargo comes.
func _melted():
	var c = current
	current = null
	current_ready = false
	melt_left = -1.0
	aiming = false
	pull = Vector2.ZERO
	aim.queue_redraw()
	melt_ring.queue_redraw()
	popup.emit("MELTED!", c.global_position + Vector2(40, -70), C_BAD, 42)
	Fx.splash(fx_root, c.global_position + Vector2(0, c.half_height()))
	Sfx.play("splash", -6.0)
	cargo_resolved.emit(c.kind, false, "melted")
	if verbose:
		print("  cargo ice melted in hand")
	c.queue_free()
	queue_changed.emit(remaining_types())
	progress_changed.emit(delivered, work_left())
	_check_end()
	get_tree().create_timer(NEXT_DELAY, false).timeout.connect(spawn_next)


func _throw():
	var c = current
	var vel = launch_velocity(pull)
	c.modulate.a = 1.0
	melt_left = -1.0
	if melt_ring:
		melt_ring.queue_redraw()
	current = null
	current_ready = false
	pull = Vector2.ZERO
	aim.queue_redraw()
	c.resolved.connect(_on_resolved)
	c.launch(vel, wind)
	thrown += 1
	in_flight += 1
	_air_kinds[c.kind] = _air_kinds.get(c.kind, 0) + 1
	Sfx.play("whoosh", -6.0, randf_range(0.95, 1.1))
	if thrown == 1:
		first_throw.emit()
		clock_running = time_limit > 0.0
	queue_changed.emit(remaining_types())
	get_tree().create_timer(NEXT_DELAY, false).timeout.connect(spawn_next)


## Used by tests and the demo bot: throw the current cargo with an exact pull vector.
func throw_with_pull(p: Vector2) -> bool:
	if not can_aim():
		return false
	pull = p.limit_length(MAX_PULL)
	_throw()
	return true


func _on_resolved(c: Cargo, ok: bool, reason: String):
	in_flight -= 1
	_air_kinds[c.kind] = _air_kinds.get(c.kind, 0) - 1
	cargo_resolved.emit(c.kind, ok, reason)
	if verbose:
		print("  cargo %s -> %s (%s) at %s" % [c.kind, "IN" if ok else "out", reason, c.global_position.round()])
	var t: CargoVehicle = truck_of(c) if ok else null
	if t and too_high(c, t):
		# M14: sticks up past the bridge line, so it gets knocked off on the way out
		var p = c.global_position + Vector2(0, -50)
		popup.emit("TOO HIGH!", p, C_BAD, 40)
		Sfx.play("rim", -2.0, 0.8)
		c.linear_velocity = Vector2(-260, -320)
		c.angular_velocity = -4.0
		c.fade_out(0.3)
	elif t:
		delivered += 1
		delivered_kinds[c.kind] = delivered_kinds.get(c.kind, 0) + 1
		t.add_load(c)
		var top = c.global_position + Vector2(0, -50)
		if not c.touched_wall:
			popup.emit("SWISH!", top, C_GOLD, 46)
		else:
			popup.emit("+1", top, C_GOOD, 46)
		Fx.delivered(fx_root, c.global_position)
		Sfx.play("deliver", -5.0, 1.0 + 0.05 * min(delivered, 8))
		_check_full(t)
	else:
		var p = c.global_position
		p.x = clamp(p.x, 80, 1200)
		p.y = clamp(p.y - 40, 160, ROAD_Y - 40)
		if reason == "road" and in_water(c.global_position):
			popup.emit("SPLASH!", p, C_BAD, 38)
			Fx.splash(fx_root, Vector2(c.global_position.x, ROAD_Y - 10))
			Sfx.play("splash", -4.0)
			c.queue_free()
		elif reason == "popped":
			popup.emit("POP!", p, C_BAD, 44)
			# deferred: we're inside a physics callback and the pop un-freezes bodies
			_pop.call_deferred(c.global_position, c.info.pop_force)
			c.queue_free()
		elif reason == "broken":
			popup.emit("BROKEN!", p, C_BAD, 42)
			Fx.shatter(fx_root, c.global_position, Color("#F2C23B"))
			Sfx.play("break", -2.0)
			c.queue_free()
		elif wrong_truck(c):
			popup.emit("WRONG TRUCK!", p, C_BAD, 38)
			Sfx.play("thud", -4.0)
			c.fade_out()
		else:
			popup.emit("MISS", p, C_BAD, 38)
			Sfx.play("thud", -4.0)
			c.fade_out()
	progress_changed.emit(delivered, work_left())
	_check_end()


# ======================================================================= M15 gas canisters
const POP_RADIUS := 170.0


## A canister landed too hard: a puff of smoke pushes nearby cargo away. Cargo knocked
## out of a truck stops counting (it can land again); fragile neighbours break.
func _pop(at: Vector2, force: float):
	Fx.dust(fx_root, at, 2.2)
	Fx.ring(fx_root, at, Color(0.92, 0.92, 0.9, 0.9), 2.4)
	Sfx.play("pop", -2.0)
	for t in live_trucks():
		for l in t.loads.duplicate():
			var d: Cargo = l.cargo
			if not is_instance_valid(d) or d.global_position.distance_to(at) > POP_RADIUS:
				continue
			if t.remove_load(d):
				delivered -= 1
				delivered_kinds[d.kind] = delivered_kinds.get(d.kind, 0) - 1
				progress_changed.emit(delivered, work_left())
			var dir = (d.global_position - at).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.UP
			if d.kind == "fragile":
				popup.emit("BROKEN!", d.global_position + Vector2(0, -40), C_BAD, 38)
				Fx.shatter(fx_root, d.global_position, Color("#F2C23B"))
				d.queue_free()
				continue
			var k = 1.0 - d.global_position.distance_to(at) / POP_RADIUS
			d.relaunch()
			d.linear_velocity = dir * force * (0.5 + k) + Vector2(0, -force * 0.6)
			d.angular_velocity = randf_range(-4.0, 4.0)
			in_flight += 1
			_air_kinds[d.kind] = _air_kinds.get(d.kind, 0) + 1
	for d in get_tree().get_nodes_in_group("cargo"):
		if is_instance_valid(d) and d.flying and not d.done and d.global_position.distance_to(at) < POP_RADIUS:
			d.linear_velocity += (d.global_position - at).normalized() * force * 0.5


## M14: level.height_limit = px above the bed floor that cargo may reach.
func too_high(c: Cargo, t: CargoVehicle) -> bool:
	if not level.has("height_limit"):
		return false
	return t.global_position.y - c.top_y() > level.height_limit + 4.0


func _check_full(t: CargoVehicle):
	if t.load_count() >= cap and work_left() > 0:
		get_tree().create_timer(0.45, false).timeout.connect(func():
			if is_instance_valid(t) and t.state == "parked":
				popup.emit(t.full_text, t.top_center() + Vector2(0, -40), C_GOLD, 40)
				t.leave())


## Screen shake (the helicopter lifting off). Only the picture moves: the viewport's canvas
## transform, never the nodes, so physics isn't touched.
func shake(amount: float, time: float):
	var vp = get_viewport()
	var base = vp.canvas_transform
	var tw = create_tween()
	tw.tween_method(func(k: float):
		var a = amount * (1.0 - k)
		vp.canvas_transform = base.translated(Vector2(sin(k * 97.0), cos(k * 71.0)) * a), 0.0, 1.0, time)
	tw.tween_callback(func(): vp.canvas_transform = base)


func on_heavy_impact(pos: Vector2, impact: float):
	Fx.dust(fx_root, pos + Vector2(0, 20), clamp(impact / 900.0, 0.3, 1.2))


func _check_end():
	if ended:
		return
	var left = work_left()
	var lost_cause = delivered + left < level.goal
	# a required kind with none loaded and none left to throw: the level can't be passed
	for k in missing_kinds():
		if queue.count(k) + (1 if current and current.kind == k else 0) + _air_kinds.get(k, 0) <= 0:
			lost_cause = true
	var done_early = level.has("need") and delivered >= level.need and in_flight == 0
	if left == 0 or done_early or (lost_cause and in_flight == 0):
		ended = true
		aiming = false
		aim.queue_redraw()
		# let the stacks settle (things can still fall out), then strap it all down and score
		get_tree().create_timer(END_SETTLE, false).timeout.connect(func():
			for t in live_trucks():
				t.glue_all()
			_score())


## Express run: time is up. Nothing more can be thrown; cargo already in the air still counts.
func _time_up():
	time_left = 0.0
	clock_running = false
	timed_out = true
	queue.clear()
	_clear_pile()
	if current:
		current.queue_free()
		current = null
	current_ready = false
	melt_left = -1.0
	aiming = false
	pull = Vector2.ZERO
	aim.queue_redraw()
	popup.emit("TIME'S UP!", Vector2(640, 240), C_BAD, 60)
	Sfx.play("fail", -4.0)
	queue_changed.emit(remaining_types())
	progress_changed.emit(delivered, work_left())
	_check_end()


## Required kinds that are not in a truck right now.
func missing_kinds() -> Array:
	var out: Array = []
	for k in required:
		if delivered_kinds.get(k, 0) <= 0:
			out.append(k)
	return out


func _score():
	var stars = Levels.stars_for(level_index, delivered, thrown)
	var missing = missing_kinds()
	if not missing.is_empty():
		# a kind is missing: no pass, however much was loaded. Say so either way: the level
		# also ends early (short of the goal) once a required kind can't be loaded any more
		stars = 0
		popup.emit("NO %s LOADED!" % str(missing[0]).to_upper(), Vector2(640, 300), C_BAD, 56)
	SaveData.set_stars(level_index, stars)
	if stars > 0:
		# showcase: every loaded vehicle honks and drives off (the helicopter lifts off)
		for t in live_trucks():
			if t.is_parked():
				t.leave()
		popup.emit(["", "LEVEL CLEAR!", "GREAT!", "PERFECT!"][stars], Vector2(640, 300), C_GOLD, 72)
		if stars == 3:
			Fx.confetti(fx_root, stars)  # only a perfect load gets confetti
	get_tree().create_timer(1.3 if stars > 0 else 0.9, false).timeout.connect(func():
		finished.emit(stars, delivered, level.cargo.length()))


## Delivered loads: anything that has left the bed for a moment (or hit the road) has fallen out.
func _physics_process(delta: float):
	frame += 1
	for pd in pads:
		if pd.swing != 0.0:
			pd.node.rotation = pad_angle(pd, frame)
			pd.n = Vector2.UP.rotated(pd.node.rotation)
	if not ended:
		_melt_tick(delta)
		if clock_running:
			time_left -= delta
			if time_left <= 0.0:
				_time_up()
	for t in live_trucks():
		if t.state != "parked":
			continue
		for l in t.loads.duplicate():
			var c: Cargo = l.cargo
			if not is_instance_valid(c) or c.freeze:
				continue
			var on_road = false
			for b in c.get_colliding_bodies():
				if b.is_in_group("ground"):
					on_road = true
			if holds(t, c) and not on_road:
				l.out_t = 0.0
				continue
			l.out_t = l.get("out_t", 0.0) + delta
			if l.out_t > FALL_OUT_TIME or on_road:
				if verbose:
					print("  cargo %s fell out of the truck at %s" % [c.kind, c.global_position.round()])
				if t.remove_load(c):
					delivered -= 1
					delivered_kinds[c.kind] = delivered_kinds.get(c.kind, 0) - 1
					popup.emit("FELL OUT!", Vector2(clamp(c.global_position.x, 80, 1200), clamp(c.global_position.y - 40, 160, ROAD_Y - 40)), C_BAD, 38)
					Sfx.play("thud", -4.0)
					progress_changed.emit(delivered, work_left())
				c.fade_out()


# ======================================================================= per-frame
func _process(delta: float):
	_time += delta
	# clouds drift with the wind (slow leftward drift when calm)
	var cloud_speed = wind * 0.15 if wind != 0.0 else -12.0
	for c in clouds:
		c.position.x += delta * cloud_speed
		if c.position.x < -1024 * 1.3:
			c.position.x += 2 * 1024 * 1.3
		elif c.position.x > 1024 * 1.3:
			c.position.x -= 2 * 1024 * 1.3
	if wind_fx:
		for s in streaks:
			s.x += wind * 2.2 * s.speed * delta
			if wind > 0 and s.x - s.len > 1300:
				s.x = randf_range(-150, -20)
				s.y = randf_range(20, ROAD_Y - 30)
			elif wind < 0 and s.x + s.len < -20:
				s.x = randf_range(1300, 1430)
				s.y = randf_range(20, ROAD_Y - 30)
		wind_fx.queue_redraw()
	if beacon:
		var on = can_aim()
		beacon.modulate = Color(1, 1, 1, 1) if not on else Color(1.0, 1.0 + 0.25 * sin(_time * 10.0), 1.0, 1.0)
	if flag:
		flag.queue_redraw()
	for pd in pads:
		if pd.squash > 0:
			pd.squash = max(0.0, pd.squash - delta * 4.0)
			pd.vis.queue_redraw()


func _draw_aim():
	if not aiming or current == null or pull.length() < 6.0:
		return
	var p0 = current.global_position
	var v = launch_velocity(pull)
	# the guide shows the calm-air arc on purpose: the wind is for the player to read
	var acc = Vector2(0, GRAVITY)
	var guide: float = level.get("guide", 1.0)
	var t_max = 0.25 + 1.15 * guide
	var dt = 1.0 / 60.0
	var p = p0
	var t = 0.0
	var i = 0
	var blocks: Array = []
	for b in level.get("blocks", []):
		blocks.append(Rect2(b[0], b[1], b[2], b[3]))
	var pad_hit := {}
	while t < t_max:
		v += acc * dt
		p += v * dt
		t += dt
		i += 1
		for pd in pads:
			# a rocking pad is shown where it will be when the cargo gets there
			var pn = pad_normal(pd, frame + i)
			if not pad_hit.has(pd) and pad_contact(pd, p, 30.0, frame + i) and v.dot(pn) < 0:
				v -= (1.0 + pd.power) * v.dot(pn) * pn
				pad_hit[pd] = true
		if p.y > ROAD_Y:
			break
		var hit = false
		for r in blocks:
			if r.has_point(p):
				hit = true
		if hit:
			break
		if i % 4 == 0:
			var k = t / t_max
			var r = lerp(8.0, 4.0, k)
			var a = lerp(1.0, 0.25, k)
			aim.draw_circle(p, r + 2.5, Color(0.106, 0.165, 0.255, a))
			aim.draw_circle(p, r, Color(1, 1, 1, a))
	# pull band from the rest spot to the cargo
	aim.draw_line(rest_pos, p0, Color(0.106, 0.165, 0.255, 0.6), 4.0)
	var strength = pull.length() / MAX_PULL
	aim.draw_arc(p0, 46, -PI / 2, -PI / 2 + TAU * strength, 32, C_GOLD.lerp(C_BAD, strength * strength), 6.0)
