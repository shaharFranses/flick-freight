class_name Levels
extends RefCounted
## All level data. Adding a level = adding one dictionary here.
##
## cargo  : string of cargo letters, thrown in order. b=box  c=crate (heavy)  r=barrel  f=fragile
## goal   : deliveries needed to pass (1 star).  s2: 2 stars.  3 stars = every cargo delivered.
## truck  : x = bed centre, amp/period = sine drive (0 = parked), wall = rear wall height
## cap    : trucks leave when they hold this many (a new truck drives in). Leave it out to keep
##          one truck for the whole level (stacking it full is the challenge)
## wind   : sideways push in px/s^2 while airborne (+ = toward the truck); the aim guide ignores it
## blocks : static obstacles [x, y, w, h] in world pixels (y = top edge)
## guide  : fraction of the aim arc shown (1 = whole arc)
## intro  : banner shown the first time a mechanic appears
##
## Expansion keys (all optional; a missing key = mechanic off, see docs/EXPANSION_PLAN.md):
## pads   : M8 bounce pads [x, y, angle_deg, power]. (x, y) = middle of the spring face,
##          angle 0 = facing up, 90 = facing right; power = restitution (1 = elastic, >1 = boost)
## trucks : several trucks at once, instead of "truck": [{x, amp, period, wall, ferry}]
## ferry  : M10 inside a truck: {amp_y (px), amp_rot (deg), period (s)}; the truck bobs on a ferry
## water  : M10 [x0, x1] stretch of open water where the road would be (cargo there splashes)
## icy    : M11 inside a truck: true = icy bed, everything slides. Cargo letter i = ice block
##          t = tire (M12, bouncy), p = plank (M13, spins at a fixed rate, must land flat),
##          g = gas canister (M15, pops on a hard landing and knocks nearby cargo out)
## plank  : M13 {length, spin} override for this level's planks (default 150 px, 2.4 rad/s)
## fragile_hits : fragile cargo breaks on this bump (default 3); every bump before it shows a crack
## height_limit : M14 px above the bed floor; cargo sticking up past it is knocked off (a miss)
## canister : M15 {pop_speed, pop_force} override (default 950 px/s, 520)

const WORLDS = [
	{"name": "TOWN", "bg": "res://art/v2/bg/bg_town.png", "tint": Color(1, 1, 1)},
	{"name": "WOODS", "bg": "res://art/v2/bg/bg_woods.png", "tint": Color(1, 1, 1)},
	{"name": "DESERT", "bg": "res://art/v2/bg/bg_desert.png", "tint": Color(1, 1, 1)},
	{"name": "HARBOR", "backdrop": "harbor", "tint": Color(1, 1, 1), "music": "res://audio/v2/music_harbor.ogg"},
	{"name": "SNOW", "backdrop": "snow", "tint": Color(1, 1, 1), "music": "res://audio/v2/music_snow.ogg"},
	{"name": "FREIGHT YARD", "backdrop": "yard", "tint": Color(1, 1, 1), "music": "res://audio/v2/music_yard.ogg"},
]

const DATA = [
	# ---------------- TOWN ----------------
	{"world": 0, "cargo": "bbbbb", "goal": 2, "s2": 4,
		"truck": {"x": 720, "amp": 0, "period": 4.0, "wall": 46}, "guide": 1.0,
		"tutorial": true},
	{"world": 0, "cargo": "bbbbbb", "goal": 3, "s2": 4,
		"truck": {"x": 930, "amp": 0, "period": 4.0, "wall": 52}, "guide": 0.75},
	{"world": 0, "cargo": "bbbbbbb", "goal": 4, "s2": 5,
		"truck": {"x": 850, "amp": 110, "period": 5.5, "wall": 52}, "guide": 0.6,
		"intro": {"title": "ON THE MOVE", "text": "Trucks drive back and forth. Lead your throw!"}},
	{"world": 0, "cargo": "bcbcbcb", "goal": 4, "s2": 5,
		"truck": {"x": 880, "amp": 0, "period": 4.0, "wall": 52}, "guide": 0.6,
		"intro": {"title": "HEAVY CRATE", "text": "Metal crates are heavy. Pull back harder!", "icon": "crate"}},
	{"world": 0, "cargo": "bcbbcbcb", "goal": 4, "s2": 6,
		"truck": {"x": 860, "amp": 140, "period": 4.2, "wall": 56}, "guide": 0.5},
	# ---------------- WOODS ----------------
	{"world": 1, "cargo": "bbcbcbb", "goal": 4, "s2": 5,
		"truck": {"x": 900, "amp": 0, "period": 4.0, "wall": 56}, "guide": 0.55,
		"blocks": [[520, 330, 56, 295]],
		"intro": {"title": "ROADBLOCK", "text": "Lob it high over the pillar."}},
	{"world": 1, "cargo": "brbrcbr", "goal": 4, "s2": 5,
		"truck": {"x": 870, "amp": 100, "period": 4.8, "wall": 56}, "guide": 0.5,
		"intro": {"title": "BARREL", "text": "Barrels are tall and tip over. Land them gently.", "icon": "barrel"}},
	{"world": 1, "cargo": "bfbbfbf", "goal": 4, "s2": 5,
		"truck": {"x": 860, "amp": 0, "period": 4.0, "wall": 60}, "guide": 0.5,
		"intro": {"title": "FRAGILE", "text": "Every bump cracks it. The 3rd bump breaks it!", "icon": "fragile"}},
	{"world": 1, "cargo": "bcbrbcfb", "goal": 4, "s2": 6,
		"truck": {"x": 900, "amp": 120, "period": 4.0, "wall": 60}, "guide": 0.45,
		"blocks": [[400, 190, 300, 40]],
		"intro": {"title": "LOW BEAM", "text": "Keep your throws under the beam."}},
	{"world": 1, "cargo": "bcrbfcbrb", "goal": 4, "s2": 7,
		"truck": {"x": 880, "amp": 115, "period": 3.6, "wall": 60}, "guide": 0.4,
		"blocks": [[540, 360, 56, 265]]},
	# ---------------- DESERT ----------------
	{"world": 2, "cargo": "bbcbbcbb", "goal": 4, "s2": 6,
		"truck": {"x": 880, "amp": 0, "period": 4.0, "wall": 56}, "guide": 0.45, "wind": -200,
		"intro": {"title": "HEADWIND", "text": "The dotted line ignores wind. Watch the flag, throw long!", "icon": "wind"}},
	{"world": 2, "cargo": "bcbrbcbr", "goal": 4, "s2": 6,
		"truck": {"x": 840, "amp": 120, "period": 4.4, "wall": 60}, "guide": 0.4, "wind": 230},
	{"world": 2, "cargo": "rbrcrbfr", "goal": 4, "s2": 6,
		"truck": {"x": 940, "amp": 0, "period": 4.0, "wall": 84}, "guide": 0.4,
		"blocks": [[560, 300, 56, 325]],
		"intro": {"title": "TALL GATE", "text": "This truck has a high tailgate. Drop it in from above."}},
	{"world": 2, "cargo": "bcfbrcbfb", "goal": 4, "s2": 7,
		"truck": {"x": 880, "amp": 140, "period": 3.8, "wall": 60}, "guide": 0.35, "wind": -180,
		"blocks": [[420, 200, 280, 40]]},
	{"world": 2, "cargo": "bcrfbcrfbc", "goal": 5, "s2": 8,
		"truck": {"x": 900, "amp": 115, "period": 3.4, "wall": 64}, "guide": 0.3, "wind": 180,
		"blocks": [[560, 380, 56, 245]],
		"intro": {"title": "FINAL RUN", "text": "Everything at once. Good luck, driver!"}},
	# ---------------- HARBOR ----------------
	{"world": 3, "cargo": "bbbbbb", "goal": 3, "s2": 5,
		"truck": {"x": 980, "amp": 0, "period": 4.0, "wall": 52}, "guide": 0.9,
		"blocks": [[380, 300, 420, 36]],
		"pads": [[560, 579, 4, 1.1]],
		"intro": {"title": "BOUNCE PAD", "text": "Throw low under the beam and bounce it in!"}},
	{"world": 3, "cargo": "bbcbbcb", "goal": 4, "s2": 5,
		"truck": {"x": 1000, "amp": 0, "period": 4.0, "wall": 56}, "guide": 0.6,
		"blocks": [[460, -100, 56, 440]],
		"pads": [[560, 579, 4, 1.1]],
		"intro": {"title": "BANK SHOT", "text": "Sneak under the pillar, then off the pad."}},
	{"world": 3, "cargo": "bfbbfbf", "goal": 4, "s2": 6,
		"truck": {"x": 980, "amp": 0, "period": 4.0, "wall": 56}, "guide": 0.55, "wind": -120,
		"blocks": [[380, 300, 420, 36]],
		"pads": [[560, 579, 4, 1.1]]},
	{"world": 3, "cargo": "bbbbbbb", "goal": 4, "s2": 6,
		"truck": {"x": 980, "amp": 90, "period": 4.6, "wall": 56}, "guide": 0.6,
		"blocks": [[380, 300, 420, 36]],
		"pads": [[560, 579, 4, 1.1]],
		"intro": {"title": "MOVING TARGET", "text": "Bounce it in while the truck drives back and forth."}},
	{"world": 3, "cargo": "bcbcbcb", "goal": 4, "s2": 6,
		"truck": {"x": 1000, "amp": 0, "period": 4.0, "wall": 80}, "guide": 0.55,
		"blocks": [[460, -100, 56, 440]],
		"pads": [[560, 579, 4, 1.15]]},
	{"world": 3, "cargo": "brbrbrb", "goal": 4, "s2": 6,
		"truck": {"x": 990, "amp": 0, "period": 4.0, "wall": 60}, "guide": 0.5, "wind": -100,
		"blocks": [[460, -100, 56, 440]],
		"pads": [[560, 579, 4, 1.1]]},
	{"world": 3, "cargo": "bbbbbb", "goal": 3, "s2": 5,
		"truck": {"x": 960, "amp": 0, "period": 4.0, "wall": 56,
			"ferry": {"amp_y": 14, "amp_rot": 3.0, "period": 3.2}}, "guide": 0.6,
		"water": [700, 1300],
		"intro": {"title": "FERRY", "text": "The truck rides the waves. Time your throw!"}},
	{"world": 3, "cargo": "brbfrbfr", "goal": 4, "s2": 6,
		"truck": {"x": 960, "amp": 0, "period": 4.0, "wall": 60,
			"ferry": {"amp_y": 16, "amp_rot": 4.0, "period": 2.8}}, "guide": 0.5,
		"water": [700, 1300]},
	{"world": 3, "cargo": "bbcbbcbb", "goal": 5, "s2": 7,
		"truck": {"x": 1010, "amp": 0, "period": 4.0, "wall": 56,
			"ferry": {"amp_y": 14, "amp_rot": 3.0, "period": 3.0}}, "guide": 0.45,
		"blocks": [[380, 300, 420, 36]],
		"pads": [[560, 579, 4, 1.1]],
		"water": [760, 1300],
		"intro": {"title": "BOUNCE TO BOARD", "text": "Bank it off the pad onto the ferry."}},
	{"world": 3, "cargo": "bcbfbcbbfb", "goal": 6, "s2": 8,
		"truck": {"x": 1010, "amp": 0, "period": 4.0, "wall": 56,
			"ferry": {"amp_y": 14, "amp_rot": 3.0, "period": 3.0}}, "guide": 0.4, "wind": 120,
		"pads": [[560, 579, 4, 1.1]],
		"water": [760, 1300],
		"intro": {"title": "HARBOR RUN", "text": "Pads, wind and a ferry. Show the harbor how it's done!"}},
	# ---------------- SNOW ----------------
	{"world": 4, "cargo": "bibibibi", "goal": 4, "s2": 6,
		"truck": {"x": 900, "amp": 0, "period": 4.0, "wall": 56}, "guide": 0.8,
		"intro": {"title": "ICE BLOCK", "text": "Slippery! It slides until something stops it.", "icon": "ice"}},
	{"world": 4, "cargo": "bbibcbib", "goal": 4, "s2": 6,
		"truck": {"x": 880, "amp": 110, "period": 4.6, "wall": 84, "icy": true}, "guide": 0.55,
		"intro": {"title": "ICY TRUCK", "text": "The whole bed is slippery. Good thing it has a tall tailgate!"}},
	{"world": 4, "cargo": "btbtbtbt", "goal": 4, "s2": 6,
		"truck": {"x": 900, "amp": 0, "period": 4.0, "wall": 70}, "guide": 0.7,
		"intro": {"title": "TIRES", "text": "Tires bounce! Drop them in softly.", "icon": "tire"}},
	{"world": 4, "cargo": "tbtbtbtb", "goal": 4, "s2": 6,
		"truck": {"x": 980, "amp": 0, "period": 4.0, "wall": 70}, "guide": 0.55,
		"blocks": [[380, 300, 420, 36]],
		"pads": [[560, 579, 4, 1.1]]},
	{"world": 4, "cargo": "ppbpbbp", "goal": 4, "s2": 6,
		"truck": {"x": 900, "amp": 0, "period": 4.0, "wall": 52}, "guide": 0.7,
		"intro": {"title": "PLANKS", "text": "Planks spin as they fly. Land them flat!", "icon": "plank"}},
	{"world": 4, "cargo": "pbpbpbp", "goal": 3, "s2": 5,
		"truck": {"x": 900, "amp": 0, "period": 4.0, "wall": 56}, "guide": 0.5, "wind": -120,
		"plank": {"length": 150, "spin": 1.8},
		"blocks": [[480, 150, 220, 36]]},
	{"world": 4, "cargo": "ccpfcpfb", "goal": 4, "s2": 6,
		"truck": {"x": 900, "amp": 0, "period": 4.0, "wall": 60}, "guide": 0.5,
		"intro": {"title": "SHELF IT", "text": "A plank on top of crates makes a shelf for fragile cargo."}},
	{"world": 4, "cargo": "bbbbbbbb", "goal": 5, "s2": 7,
		"truck": {"x": 900, "amp": 0, "period": 4.0, "wall": 52}, "cap": 3, "guide": 0.6, "height_limit": 70,
		"intro": {"title": "LOW BRIDGE", "text": "Above the red line gets knocked off. Keep it low!"}},
	{"world": 4, "cargo": "bibbibib", "goal": 4, "s2": 6,
		"truck": {"x": 900, "amp": 0, "period": 4.0, "wall": 56}, "cap": 3, "guide": 0.5,
		"height_limit": 70},
	{"world": 4, "cargo": "tpibtpbitp", "goal": 5, "s2": 8,
		"truck": {"x": 960, "amp": 0, "period": 4.0, "wall": 64, "icy": true}, "cap": 4, "guide": 0.4, "height_limit": 96,
		"pads": [[600, 579, 4, 1.0]],
		"intro": {"title": "WHITEOUT", "text": "Ice, tires, planks and a low bridge. Stay cool!"}},
	# ---------------- FREIGHT YARD ----------------
	{"world": 5, "cargo": "bgbgbgb", "goal": 4, "s2": 6,
		"truck": {"x": 820, "amp": 0, "period": 4.0, "wall": 56}, "guide": 0.8,
		"canister": {"pop_speed": 1050},
		"intro": {"title": "GAS CANS", "text": "Land them softly or they pop and scatter the load!", "icon": "canister"}},
	{"world": 5, "cargo": "gfbgbfg", "goal": 3, "s2": 5,
		"truck": {"x": 860, "amp": 0, "period": 4.0, "wall": 56}, "cap": 4, "guide": 0.5, "height_limit": 124,
		"canister": {"pop_speed": 1050},
		"intro": {"title": "ORDER MATTERS", "text": "Keep cans away from fragile cargo, and stay under the line."}},
	{"world": 5, "cargo": "bcbcbcbcbc", "goal": 5, "s2": 8,
		"truck": {"x": 900, "amp": 120, "period": 3.8, "wall": 60}, "guide": 0.4, "wind": 120,
		"intro": {"title": "RUSH HOUR", "text": "Moving truck, tailwind, heavy crates. Stack them tight!"}},
	{"world": 5, "cargo": "igbigbig", "goal": 4, "s2": 6,
		"truck": {"x": 880, "amp": 0, "period": 4.0, "wall": 70,
			"ferry": {"amp_y": 12, "amp_rot": 2.5, "period": 3.0}}, "guide": 0.45,
		"canister": {"pop_speed": 1100},
		"water": [640, 1300]},
	{"world": 5, "cargo": "bcrfitpgbcb", "goal": 5, "s2": 8,
		"truck": {"x": 1000, "amp": 0, "period": 4.0, "wall": 64,
			"ferry": {"amp_y": 12, "amp_rot": 2.5, "period": 3.2}}, "cap": 6, "guide": 0.4, "wind": -80,
		"height_limit": 130,
		"pads": [[560, 579, 4, 1.1]],
		"water": [760, 1300],
		"intro": {"title": "GRAND FINALE", "text": "One of everything. You've got this, driver!"}},
]

const LETTER = {"b": "box", "c": "crate", "r": "barrel", "f": "fragile",
	"i": "ice", "t": "tire", "p": "plank", "g": "canister"}


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


static func levels_in_world(w: int) -> Array:
	var out: Array = []
	for i in DATA.size():
		if DATA[i].world == w:
			out.append(i)
	return out


static func world_of(i: int) -> Dictionary:
	return WORLDS[get_level(i).world]
