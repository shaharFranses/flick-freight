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
var spin := 0.0  # M13: fixed spin (rad/s); 0 = ordinary cargo
var slides := false  # M11: ice cargo
var bouncy := false  # M12
var pop_speed := 0.0  # M15: canister pops above this landing speed
var raw_blocks: Array = []
var pads: Array = []
var last_dist := INF  # landing distance from the target spot of the last scored throw


func _init(game):
	g = game
	p0 = g.current.global_position
	h = g.current.info.size * 0.5
	mult = g.current.power_mult()
	pads = g.pads
	var info: Dictionary = g.current.info
	spin = info.get("spin", 0.0)
	slides = g.current.kind == "ice"
	bouncy = g.current.kind == "tire"
	pop_speed = info.get("pop_speed", 0.0)
	# cargo spins in flight, so keep its corner radius clear of obstacles
	var r = h.length()
	for b in g.level.get("blocks", []):
		blocks.append(Rect2(b[0], b[1], b[2], b[3]).grow(r))
		raw_blocks.append(Rect2(b[0], b[1], b[2], b[3]))
	for t in _game_trucks():
		trucks.append(_truck_info(t))


func _game_trucks() -> Array:
	var out: Array = []
	for t in g.live_trucks():
		if t.is_parked():
			out.append(t)
	return out


## Load floor x-profile: height of the stack (px above the floor) in 10 px columns.
func _truck_info(t: CargoVehicle) -> Dictionary:
	var pr: Dictionary = t.sim_profile()
	var W: float = pr.floor_w
	var cols = int(W / 10.0)
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
			var x = -W * 0.5 + i * 10.0 + 5.0
			if abs(x - l.offset.x) < half.x + 6:
				surface[i] = max(surface[i], top)
	# aim for the lowest column that fits the cargo, closest to slightly front-of-centre
	var best_x = 0.0
	var best = INF
	var margin = h.x + 10.0
	for i in cols:
		var x = -W * 0.5 + i * 10.0 + 5.0
		if x < -W * 0.5 + margin or x > W * 0.5 - margin:
			continue
		var hgt = 0.0
		for j in cols:
			var xj = -W * 0.5 + j * 10.0 + 5.0
			if abs(xj - x) < h.x:
				hgt = max(hgt, surface[j])
		var cost = hgt * 4.0 + abs(x - 40.0) * 0.2
		if cost < best:
			best = cost
			best_x = x
	return {"truck": t, "target_x": best_x, "surface": surface, "profile": pr,
		"slippery": slides or pr.slippery}


## Axis-aligned half extents of the cargo rotated by `rot`.
func _extent(rot: float) -> Vector2:
	return Vector2(abs(h.x * cos(rot)) + abs(h.y * sin(rot)), abs(h.x * sin(rot)) + abs(h.y * cos(rot)))


func surface_at(info: Dictionary, local_x: float) -> float:
	var s: Array = info.surface
	var hgt = 0.0
	var W: float = info.profile.floor_w
	for i in s.size():
		var x = -W * 0.5 + i * 10.0 + 5.0
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
		if spin != 0.0:
			# M13: exact extents of the spinning plank
			var e = _extent(spin * t)
			for r in raw_blocks:
				if r.grow_individual(e.x, e.y, e.x, e.y).has_point(p):
					return INF
		else:
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
	var tr: CargoVehicle = info.truck
	var pr: Dictionary = info.profile
	var pose = tr.predict_pose(t)
	var l = (p - pose[0]).rotated(-pose[1])
	var half = pr.floor_w * 0.5
	# rear wall (left), front block e.g. bulkhead + cab (right); spinning cargo reaches out to its corners
	var rr = h.length() if spin == 0.0 else max(_extent(spin * t).x, _extent(spin * t).y)
	if l.x + rr > -half - pr.rear_t and l.x - rr < -half and l.y + rr > -pr.rear_h:
		return -2.0
	if l.x + rr > pr.front_x0 and l.x - rr < pr.front_x0 + pr.front_w and l.y + rr > -pr.front_h:
		return -2.0
	var ext = h if spin == 0.0 else _extent(spin * t)
	if v.y > 0 and abs(l.x) < half - h.x * 0.5:
		var floor_y = -surface_at(info, l.x)
		if l.y + ext.y >= floor_y:
			# M14: the stack must stay under the bridge line
			if tr.height_limit > 0 and -floor_y + ext.y * 2.0 > tr.height_limit:
				return INF
			last_dist = abs(l.x - info.target_x)
			var rel_vx = abs(v.x - tr.predict_vx(t))
			# prefer soft, steep landings: forward speed makes cargo slide into the bulkhead
			var sc = last_dist + rel_vx * 0.05 + v.length() * 0.01
			if info.slippery:
				sc += rel_vx * 0.2  # ice keeps sliding on whatever it carries
			if bouncy:
				sc += abs(v.y) * 0.08  # tires bounce out of hard landings
			if pop_speed > 0.0:
				if v.length() > pop_speed * 0.92:
					return INF  # would pop
				sc += v.length() * 0.05
			if spin != 0.0:
				var a = fposmod(spin * t, PI)
				# any angle counts, but a flatter landing settles more calmly
				sc += rad_to_deg(min(a, PI - a)) * 0.5
			return sc
	return -1.0
