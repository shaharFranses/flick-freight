class_name Levels
extends RefCounted
## All level data. Adding a level = adding one dictionary here.
##
## cargo  : string of cargo letters, thrown in order. b=box  c=crate (heavy)  r=barrel  f=fragile
## goal   : deliveries needed to pass (1 star).  s2: 2 stars.  3 stars = every cargo delivered.
## truck  : x = bed centre, amp/period = sine drive (0 = parked), wall = rear wall height
## cap    : trucks leave when they hold this many (a new truck drives in)
## wind   : sideways push in px/s^2 (+ = toward the truck)
## blocks : static obstacles [x, y, w, h] in world pixels (y = top edge)
## guide  : fraction of the aim arc shown (1 = whole arc)
## intro  : banner shown the first time a mechanic appears

const WORLDS = [
	{"name": "TOWN", "bg": "res://art/v2/bg/bg_town.png", "tint": Color(1, 1, 1)},
	{"name": "WOODS", "bg": "res://art/v2/bg/bg_woods.png", "tint": Color(1, 1, 1)},
	{"name": "DESERT", "bg": "res://art/v2/bg/bg_desert.png", "tint": Color(1, 1, 1)},
]

const DATA = [
	# ---------------- TOWN ----------------
	{"world": 0, "cargo": "bbbbb", "goal": 2, "s2": 4,
		"truck": {"x": 720, "amp": 0, "period": 4.0, "wall": 46}, "cap": 5, "guide": 1.0,
		"tutorial": true},
	{"world": 0, "cargo": "bbbbbb", "goal": 3, "s2": 4,
		"truck": {"x": 930, "amp": 0, "period": 4.0, "wall": 52}, "cap": 6, "guide": 0.75},
	{"world": 0, "cargo": "bbbbbbb", "goal": 4, "s2": 5,
		"truck": {"x": 850, "amp": 110, "period": 5.5, "wall": 52}, "cap": 4, "guide": 0.6,
		"intro": {"title": "ON THE MOVE", "text": "Trucks drive back and forth. Lead your throw!"}},
	{"world": 0, "cargo": "bcbcbcb", "goal": 4, "s2": 5,
		"truck": {"x": 880, "amp": 0, "period": 4.0, "wall": 52}, "cap": 4, "guide": 0.6,
		"intro": {"title": "HEAVY CRATE", "text": "Metal crates are heavy. Pull back harder!", "icon": "crate"}},
	{"world": 0, "cargo": "bcbbcbcb", "goal": 4, "s2": 6,
		"truck": {"x": 860, "amp": 140, "period": 4.2, "wall": 56}, "cap": 4, "guide": 0.5},
	# ---------------- WOODS ----------------
	{"world": 1, "cargo": "bbcbcbb", "goal": 4, "s2": 5,
		"truck": {"x": 900, "amp": 0, "period": 4.0, "wall": 56}, "cap": 4, "guide": 0.55,
		"blocks": [[520, 330, 56, 295]],
		"intro": {"title": "ROADBLOCK", "text": "Lob it high over the pillar."}},
	{"world": 1, "cargo": "brbrcbr", "goal": 4, "s2": 5,
		"truck": {"x": 870, "amp": 100, "period": 4.8, "wall": 56}, "cap": 4, "guide": 0.5,
		"intro": {"title": "BARREL", "text": "Barrels are tall and tip over. Land them gently.", "icon": "barrel"}},
	{"world": 1, "cargo": "bfbbfbf", "goal": 4, "s2": 5,
		"truck": {"x": 860, "amp": 0, "period": 4.0, "wall": 60}, "cap": 4, "guide": 0.5,
		"intro": {"title": "FRAGILE", "text": "Breaks if it hits a wall or the road. Land it clean!", "icon": "fragile"}},
	{"world": 1, "cargo": "bcbrbcfb", "goal": 4, "s2": 6,
		"truck": {"x": 900, "amp": 120, "period": 4.0, "wall": 60}, "cap": 4, "guide": 0.45,
		"blocks": [[400, 190, 300, 40]],
		"intro": {"title": "LOW BEAM", "text": "Keep your throws under the beam."}},
	{"world": 1, "cargo": "bcrbfcbrb", "goal": 4, "s2": 7,
		"truck": {"x": 880, "amp": 150, "period": 3.6, "wall": 60}, "cap": 3, "guide": 0.4,
		"blocks": [[540, 360, 56, 265]]},
	# ---------------- DESERT ----------------
	{"world": 2, "cargo": "bbcbbcbb", "goal": 4, "s2": 6,
		"truck": {"x": 880, "amp": 0, "period": 4.0, "wall": 56}, "cap": 4, "guide": 0.45, "wind": -140,
		"intro": {"title": "HEADWIND", "text": "Wind pushes your cargo. Watch the flag!", "icon": "wind"}},
	{"world": 2, "cargo": "bcbrbcbr", "goal": 4, "s2": 6,
		"truck": {"x": 840, "amp": 120, "period": 4.4, "wall": 60}, "cap": 4, "guide": 0.4, "wind": 160},
	{"world": 2, "cargo": "rbrcrbfr", "goal": 4, "s2": 6,
		"truck": {"x": 940, "amp": 0, "period": 4.0, "wall": 84}, "cap": 4, "guide": 0.4,
		"blocks": [[560, 300, 56, 325]],
		"intro": {"title": "TALL GATE", "text": "This truck has a high tailgate. Drop it in from above."}},
	{"world": 2, "cargo": "bcfbrcbfb", "goal": 4, "s2": 7,
		"truck": {"x": 880, "amp": 140, "period": 3.8, "wall": 60}, "cap": 3, "guide": 0.35, "wind": -120,
		"blocks": [[420, 200, 280, 40]]},
	{"world": 2, "cargo": "bcrfbcrfbc", "goal": 5, "s2": 8,
		"truck": {"x": 900, "amp": 170, "period": 3.4, "wall": 64}, "cap": 3, "guide": 0.3, "wind": 120,
		"blocks": [[560, 380, 56, 245]],
		"intro": {"title": "FINAL RUN", "text": "Everything at once. Good luck, driver!"}},
]

const LETTER = {"b": "box", "c": "crate", "r": "barrel", "f": "fragile"}


static func count() -> int:
	return DATA.size()


static func get_level(i: int) -> Dictionary:
	return DATA[clampi(i, 0, DATA.size() - 1)]


static func cargo_list(i: int) -> Array:
	var out: Array = []
	for ch in get_level(i).cargo:
		out.append(LETTER[ch])
	return out


static func stars_for(i: int, delivered: int) -> int:
	var lv = get_level(i)
	var total = lv.cargo.length()
	if delivered >= total:
		return 3
	if delivered >= lv.get("s2", total):
		return 2
	if delivered >= lv.goal:
		return 1
	return 0


static func world_of(i: int) -> Dictionary:
	return WORLDS[get_level(i).world]
