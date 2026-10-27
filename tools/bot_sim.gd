class_name BotSim
extends RefCounted
## Throw model for the QA bot's search solver. Steps one candidate throw at 60 fps
## through the level (wind, obstacles, the truck's motion and walls) and returns a
## score: lower is better, INF = the throw can't work. Deterministic, no engine physics,
## so the bot can try hundreds of candidates per throw.

const DT := 1.0 / 60.0
const MAX_T := 3.5
const GOOD := 60.0  # landing this close (px) to the target spot counts as a good throw

var g  # Game
var p0: Vector2
var h: Vector2  # cargo half size
var mult := 1.0
var blocks: Array = []
var trucks: Array = []  # [{truck, target_x, surface: Array}]
var color := -1
var pads: Array = []
var last_dist := INF  # landing distance from the target spot of the last scored throw


func _init(game):
	g = game
	p0 = g.current.global_position
	h = g.current.info.size * 0.5
	mult = g.current.power_mult()
	color = g.current.color
	pads = g.pads
	# cargo spins in flight, so keep its corner radius clear of obstacles
	var r = h.length()
	for b in g.level.get("blocks", []):
		blocks.append(Rect2(b[0], b[1], b[2], b[3]).grow(r))
	for t in _game_trucks():
		trucks.append(_truck_info(t))


func _game_trucks() -> Array:
	var out: Array = []
	for t in g.live_trucks():
		if t.is_parked():
			out.append(t)
	return out


## Bed floor x-profile: height of the stack (px above the floor) in 10 px columns.
func _truck_info(t: Truck) -> Dictionary:
	var cols = int(Truck.BED_W / 10.0)
	var surface: Array = []
	surface.resize(cols)
	surface.fill(0.0)
	for l in t.loads:
		var c: Cargo = l.cargo
		if not is_instance_valid(c):
			continue
		var half = c.info.size * 0.5
		var top = -(l.offset.y - half.y)  # local y is negative upward
		for i in cols:
			var x = -Truck.BED_W * 0.5 + i * 10.0 + 5.0
			if abs(x - l.offset.x) < half.x + 6:
				surface[i] = max(surface[i], top)
	# aim for the lowest column that fits the cargo, closest to slightly front-of-centre
	var best_x = 0.0
	var best = INF
	var margin = h.x + 10.0
	for i in cols:
		var x = -Truck.BED_W * 0.5 + i * 10.0 + 5.0
		if x < -Truck.BED_W * 0.5 + margin or x > Truck.BED_W * 0.5 - margin:
			continue
		var hgt = 0.0
		for j in cols:
			var xj = -Truck.BED_W * 0.5 + j * 10.0 + 5.0
			if abs(xj - x) < h.x:
				hgt = max(hgt, surface[j])
		var cost = hgt * 4.0 + abs(x - 40.0) * 0.2
		if cost < best:
			best = cost
			best_x = x
	# M9: landing in a truck of another colour is a miss
	var wrong = color >= 0 and t.color >= 0 and t.color != color
	return {"truck": t, "target_x": best_x, "surface": surface, "wrong": wrong}


func truck_pos(t: Truck, dt: float) -> Vector2:
	var p = t.global_position
	if t.amp > 0:
		p.x = t.base_x + t.amp * sin(TAU * (t._t + dt) / t.period)
	if not t.ferry.is_empty():
		p.y = t.ferry_pose(dt)[0]
	return p


func truck_rot(t: Truck, dt: float) -> float:
	return 0.0 if t.ferry.is_empty() else t.ferry_pose(dt)[1]


func _truck_vx(t: Truck, dt: float) -> float:
	if t.amp <= 0:
		return 0.0
	return t.amp * TAU / t.period * cos(TAU * (t._t + dt) / t.period)


func surface_at(info: Dictionary, local_x: float) -> float:
	var s: Array = info.surface
	var hgt = 0.0
	for i in s.size():
		var x = -Truck.BED_W * 0.5 + i * 10.0 + 5.0
		if abs(x - local_x) < h.x:
			hgt = max(hgt, s[i])
	return hgt


func score(pull: Vector2) -> float:
	last_dist = INF
	var v = pull * Game.POWER * mult
	var p = p0
	var t = 0.0
	var inside := {}
	while t < MAX_T:
		v += Vector2(g.wind, Game.GRAVITY) * DT
		p += v * DT
		t += DT
		# M8: pads reflect on entry, like the game's Area2D
		for pd in pads:
			var touching = g.pad_contact(pd, p, h.y)
			if touching and not inside.has(pd) and v.dot(pd.n) < 0:
				v -= (1.0 + pd.power) * v.dot(pd.n) * pd.n
			if touching:
				inside[pd] = true
			else:
				inside.erase(pd)
		if p.y + h.y > Game.ROAD_Y or p.x > 1400 or p.x < -100:
			return INF
		if p.x - h.x < Game.DOCK_RIGHT and p.y + h.y > Game.DOCK_TOP + 2:
			return INF  # scraped the dock edge
		for r in blocks:
			if r.has_point(p):
				return INF
		for info in trucks:
			var r = _vs_truck(info, p, v, t)
			if r >= 0.0:
				return r
			if r == -2.0:
				return INF
	return INF


## -1 = still flying, -2 = hit a wall / the cab, >= 0 = landed in the bed (score).
func _vs_truck(info: Dictionary, p: Vector2, v: Vector2, t: float) -> float:
	var tr: Truck = info.truck
	var o = truck_pos(tr, t)
	var l = (p - o).rotated(-truck_rot(tr, t))
	var half = Truck.BED_W * 0.5
	# tailgate (left), bulkhead + cab (right)
	if l.x + h.x > -half - Truck.WALL_T and l.x - h.x < -half and l.y + h.y > -tr.wall_h:
		return -2.0
	if l.x + h.x > half and l.x - h.x < half + Truck.WALL_T + Truck.CAB_W and l.y + h.y > -Truck.FRONT_H:
		return -2.0
	if v.y > 0 and abs(l.x) < half - h.x * 0.5:
		var floor_y = -surface_at(info, l.x)
		if l.y + h.y >= floor_y:
			if info.wrong:
				return INF
			last_dist = abs(l.x - info.target_x)
			# prefer soft, steep landings: forward speed makes cargo slide into the bulkhead
			return last_dist + abs(v.x - _truck_vx(tr, t)) * 0.05 + v.length() * 0.01
	return -1.0
