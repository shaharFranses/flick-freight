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
##          t = tire (M12, bouncy), p = plank (M13, long, spins at a fixed rate; counts at any angle),
##          g = gas canister (M15, pops on a hard landing and knocks nearby cargo out)
## plank  : M13 {length, spin} override for this level's planks (default 150 px, 2.4 rad/s)
## fragile_hits : fragile cargo breaks on this bump (default 3); every bump before it shows a crack
## height_limit : M14 px above the bed floor; cargo sticking up past it is knocked off (a miss)
## canister : M15 {pop_speed, pop_force} override (default 950 px/s, 520)
##
## Plan 2 (docs/EXPANSION_PLAN_2.md). IDs 41+ are appended; "act": 2 puts a level in its
## world's Act II.
## vehicle : inside a truck config: "moto" (V1), "pickup" (V2), "garbage" (V3), "dump" (V5),
##           "flatbed" (V6), "flatcar" (V7, rolls across; "once": true = no new one after it),
##           "heli" (V8, net on a swinging cable), "balloon" (V9, rising / sinking basket),
##           "mailvan" (V4, slot for parcels), "foodtruck" (V10, serving window)
##           (scripts/vehicles.gd)
## movers  : moving obstacles [{"type", "phase", ...}] (scripts/movers.gd):
##           crane (M16), garage_door (M17), bus (M18, also kind "train"), ski_lift (M19),
##           swinging_log (M20), windmill (M21), forklift (M22), tumbleweed, conveyor (M23),
##           tower_crane (M16 variant: a beam on a trolley that slides along the jib)
## need / throw_stars : finish once `need` are loaded; 3 stars within throw_stars[0] throws,
##           2 stars within throw_stars[1] (few-throws levels, e.g. the motorcycle)

## Level IDs: a level's ID is its index in DATA and never changes (saves are keyed by it).
## New levels are only ever appended to DATA. The order players meet them in is separate:
## world by world in WORLD_ORDER, each world's Act I then its Act II ("act": 2).
## A world with "unlock_stars" opens at that star total; otherwise once the world before it
## (in WORLD_ORDER) has its Act I done.

const WORLDS = [
	{"name": "TOWN", "bg": "res://art/v2/bg/bg_town.png", "tint": Color(1, 1, 1), "bridge": "stone", "icon": "moto"},
	{"name": "WOODS", "bg": "res://art/v2/bg/bg_woods.png", "tint": Color(1, 1, 1), "bridge": "wood", "icon": "pickup"},
	{"name": "DESERT", "bg": "res://art/v2/bg/bg_desert.png", "tint": Color(1, 1, 1), "bridge": "rock", "icon": "dump"},
	{"name": "HARBOR", "backdrop": "harbor", "tint": Color(1, 1, 1), "bridge": "steel", "music": "res://audio/v2/music_harbor.ogg", "icon": "ferry"},
	{"name": "SNOW", "backdrop": "snow", "tint": Color(1, 1, 1), "bridge": "snow_rock", "music": "res://audio/v2/music_snow.ogg", "icon": "lift"},
	{"name": "FREIGHT YARD", "backdrop": "yard", "tint": Color(1, 1, 1), "bridge": "steel", "music": "res://audio/v2/music_yard.ogg", "icon": "flatcar"},
	{"name": "SKY PORT", "backdrop": "sky", "tint": Color(1, 1, 1), "bridge": "steel", "music": "res://audio/v2/music_sky.ogg", "icon": "heli",
		"unlock_stars": 150},
	{"name": "DOWNTOWN", "backdrop": "city", "tint": Color(1, 1, 1), "bridge": "stone", "music": "res://audio/v2/music_city.ogg", "icon": "mailvan",
		"unlock_stars": 90},
	{"name": "CONSTRUCTION", "backdrop": "site", "tint": Color(1, 1, 1), "bridge": "steel", "music": "res://audio/v2/music_site.ogg", "icon": "crane",
		"unlock_stars": 120},
]

## Display / play order of the worlds (indices into WORLDS).
const WORLD_ORDER = [0, 1, 2, 3, 4, 5, 7, 8, 6]  # Sky Port is the finale

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
		"intro": {"title": "PLANKS", "text": "Planks spin as they fly. A tilted plank still counts!", "icon": "plank"}},
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
	{"world": 4, "cargo": "tpibtpbitp", "goal": 4, "s2": 7,
		"truck": {"x": 960, "amp": 0, "period": 4.0, "wall": 64, "icy": true}, "cap": 4, "guide": 0.4, "height_limit": 110,
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
	# ================= Plan 2 =================
	# ---------------- TOWN, Act II (IDs 41-45) ----------------
	{"world": 0, "act": 2, "cargo": "bbbbbb", "goal": 3, "s2": 5,
		"truck": {"x": 900, "amp": 0, "period": 4.0, "wall": 52}, "guide": 0.8,
		"movers": [{"type": "garage_door", "x": 600, "top": 250, "period": 240, "open": 120}],
		"intro": {"title": "GARAGE DOOR", "text": "Throw through while it's open. Amber light = closing!"}},
	{"world": 0, "act": 2, "cargo": "bbbbbbbb", "goal": 3, "need": 3, "throw_stars": [3, 5],
		"truck": {"x": 820, "amp": 0, "period": 4.0, "vehicle": "moto"}, "cap": 1, "guide": 0.8,
		"intro": {"title": "COURIERS", "text": "One parcel per bike. 3 bikes, as few throws as you can!"}},
	{"world": 0, "act": 2, "cargo": "bcbcbbc", "goal": 4, "s2": 6,
		"truck": {"x": 960, "amp": 0, "period": 4.0, "wall": 56}, "guide": 0.6,
		"movers": [{"type": "bus", "period": 420, "speed": 9.0}],
		"intro": {"title": "BUS STOP", "text": "Wait for the bus to pass. Red lights = it's coming!"}},
	{"world": 0, "act": 2, "cargo": "bbbbbb", "goal": 3, "s2": 5,
		"truck": {"x": 900, "amp": 0, "period": 4.0, "vehicle": "garbage"}, "guide": 0.7,
		"intro": {"title": "GARBAGE TRUCK", "text": "Drop it through the hopper: throw high and steep."}},
	{"world": 0, "act": 2, "cargo": "bbfbbfb", "goal": 3, "need": 3, "throw_stars": [4, 6],
		"truck": {"x": 780, "amp": 0, "period": 4.0, "vehicle": "moto"}, "cap": 1, "guide": 0.5,
		"movers": [{"type": "garage_door", "x": 540, "top": 200, "period": 240, "open": 120}],
		"intro": {"title": "LAST DELIVERY", "text": "Motorcycle behind a closing door. Make every throw count."}},
	# ---------------- HARBOR, Act II (IDs 46-50) ----------------
	{"world": 3, "act": 2, "cargo": "bbbbbb", "goal": 3, "s2": 5,
		"truck": {"x": 980, "amp": 0, "period": 4.0, "wall": 52}, "guide": 0.8,
		"movers": [{"type": "crane", "x": 620, "y": 100, "length": 200, "swing": 28, "period": 200}],
		"intro": {"title": "CRANE", "text": "The container swings. Listen for the creak and time it!"}},
	{"world": 3, "act": 2, "cargo": "bbbbbbb", "goal": 4, "s2": 6,
		"truck": {"x": 1000, "amp": 0, "period": 4.0, "wall": 56}, "guide": 0.6,
		"blocks": [[380, 300, 420, 36]],
		"pads": [[560, 579, 4, 1.1]],
		"movers": [{"type": "forklift", "x0": 340, "x1": 470, "period": 300, "forks": 80}],
		"intro": {"title": "FORKLIFT", "text": "It patrols the quay. Bounce off the pad behind it."}},
	{"world": 3, "act": 2, "cargo": "bcbcbcb", "goal": 4, "s2": 6,
		"truck": {"x": 990, "amp": 0, "period": 4.0, "wall": 56}, "guide": 0.5, "wind": -100,
		"movers": [{"type": "crane", "x": 600, "y": 100, "length": 210, "swing": 22, "period": 260}]},
	{"world": 3, "act": 2, "cargo": "bbcbbbcb", "goal": 4, "s2": 7,
		"truck": {"x": 1000, "amp": 0, "period": 4.4, "wall": 56}, "guide": 0.45,
		"movers": [{"type": "crane", "x": 650, "y": 100, "length": 150, "swing": 22, "period": 240},
			{"type": "forklift", "x0": 340, "x1": 470, "period": 260, "forks": 80, "phase": 60}]},
	{"world": 3, "act": 2, "cargo": "bbcbfbcbb", "goal": 5, "s2": 7,
		"truck": {"x": 1010, "amp": 0, "period": 4.0, "wall": 56,
			"ferry": {"amp_y": 14, "amp_rot": 3.0, "period": 3.0}}, "guide": 0.4,
		"water": [760, 1300],
		"movers": [{"type": "crane", "x": 700, "y": 100, "length": 190, "swing": 24, "period": 260}],
		"intro": {"title": "DOCK BOSS", "text": "A ferry behind a swinging container. Timing is everything."}},
	# ---------------- WOODS, Act II (IDs 51-55) ----------------
	{"world": 1, "act": 2, "cargo": "bbbbbb", "goal": 3, "s2": 5,
		"truck": {"x": 940, "amp": 0, "period": 4.0, "wall": 52}, "guide": 0.8,
		"movers": [{"type": "swinging_log", "x": 600, "y": -40, "length": 250, "swing": 30, "period": 220}],
		"intro": {"title": "SWINGING LOG", "text": "A log swings on its ropes. Throw behind it as it passes."}},
	{"world": 1, "act": 2, "cargo": "bbbbb", "goal": 3, "s2": 4,
		"truck": {"x": 880, "amp": 0, "period": 4.0, "vehicle": "pickup"}, "guide": 0.7,
		"intro": {"title": "PICKUP", "text": "Short bed, low sides. Soft throws stay in; hard ones slide out!"}},
	{"world": 1, "act": 2, "cargo": "bcbbcb", "goal": 3, "s2": 5,
		"truck": {"x": 960, "amp": 0, "period": 4.0, "wall": 56}, "guide": 0.6, "wind": 80,
		"movers": [{"type": "swinging_log", "x": 560, "y": -40, "length": 240, "swing": 28, "period": 200},
			{"type": "swinging_log", "x": 760, "y": -60, "length": 250, "swing": 28, "period": 200, "phase": 100}]},
	{"world": 1, "act": 2, "cargo": "bbbbbb", "goal": 3, "s2": 4,
		"truck": {"x": 900, "amp": 0, "period": 4.0, "vehicle": "pickup"}, "guide": 0.5, "wind": -90,
		"movers": [{"type": "swinging_log", "x": 640, "y": -40, "length": 250, "swing": 30, "period": 240}]},
	{"world": 1, "act": 2, "cargo": "bbcbbcb", "goal": 3, "s2": 5,
		"truck": {"x": 920, "amp": 0, "period": 4.0, "vehicle": "pickup"}, "guide": 0.4, "wind": 50,
		"movers": [{"type": "swinging_log", "x": 540, "y": -40, "length": 240, "swing": 28, "period": 220},
			{"type": "swinging_log", "x": 740, "y": -60, "length": 250, "swing": 28, "period": 220, "phase": 110}],
		"intro": {"title": "WOODS BOSS", "text": "A pickup, two logs out of step and a tailwind. Stay soft."}},
	# ---------------- DESERT, Act II (IDs 56-60) ----------------
	{"world": 2, "act": 2, "cargo": "bbbbbb", "goal": 3, "s2": 5,
		"truck": {"x": 960, "amp": 0, "period": 4.0, "wall": 52}, "guide": 0.8,
		"movers": [{"type": "windmill", "x": 620, "y": 330, "blade": 150, "period": 360, "blades": 3}],
		"intro": {"title": "WINDMILL", "text": "Thread your throws between the turning blades."}},
	{"world": 2, "act": 2, "cargo": "bcbcbb", "goal": 3, "s2": 5,
		"truck": {"x": 900, "amp": 0, "period": 4.0, "vehicle": "dump", "tilt": 8}, "guide": 0.7,
		"intro": {"title": "DUMP TRUCK", "text": "The bed tips back. Land heavy crates first as stoppers."}},
	{"world": 2, "act": 2, "cargo": "bbbbbbb", "goal": 4, "s2": 6,
		"truck": {"x": 920, "amp": 90, "period": 5.0, "wall": 56}, "guide": 0.6,
		"movers": [{"type": "tumbleweed", "x0": 330, "x1": 760, "period": 300, "hop": 120, "radius": 36}],
		"intro": {"title": "TUMBLEWEED", "text": "It bounces across the sand. Don't let it bat your box away."}},
	{"world": 2, "act": 2, "cargo": "cbcbbcb", "goal": 4, "s2": 6,
		"truck": {"x": 940, "amp": 0, "period": 4.0, "vehicle": "dump", "tilt": 8}, "guide": 0.5,
		"movers": [{"type": "windmill", "x": 600, "y": 320, "blade": 140, "period": 300, "blades": 3}]},
	{"world": 2, "act": 2, "cargo": "ccbcbbcb", "goal": 4, "s2": 6,
		"truck": {"x": 900, "amp": 0, "period": 4.0, "vehicle": "dump", "tilt": 8}, "guide": 0.4,
		"movers": [{"type": "windmill", "x": 600, "y": 300, "blade": 130, "period": 360, "blades": 3},
			{"type": "tumbleweed", "x0": 300, "x1": 480, "period": 240, "hop": 80, "radius": 32}],
		"intro": {"title": "DESERT BOSS", "text": "Dump truck behind a windmill. Crates first, then the rest."}},
	# ---------------- SNOW, Act II (IDs 61-65) ----------------
	{"world": 4, "act": 2, "cargo": "bbbbbb", "goal": 3, "s2": 5,
		"truck": {"x": 960, "amp": 0, "period": 4.0, "wall": 52}, "guide": 0.8,
		"movers": [{"type": "ski_lift", "ax": 400, "ay": 200, "bx": 860, "by": 300, "chairs": 3, "speed": 110}],
		"intro": {"title": "SKI LIFT", "text": "Land on a chair and ride it, or bank off it into the truck."}},
	{"world": 4, "act": 2, "cargo": "bibibb", "goal": 3, "s2": 5,
		"truck": {"x": 980, "amp": 0, "period": 4.0, "wall": 56, "icy": true}, "guide": 0.6,
		"movers": [{"type": "ski_lift", "ax": 380, "ay": 220, "bx": 880, "by": 310, "chairs": 3, "speed": 120}]},
	{"world": 4, "act": 2, "cargo": "iiibbii", "goal": 4, "s2": 6,
		"truck": {"x": 1000, "amp": 0, "period": 4.0, "wall": 56}, "guide": 0.5,
		"movers": [{"type": "ski_lift", "ax": 360, "ay": 200, "bx": 900, "by": 330, "chairs": 3, "speed": 110}]},
	{"world": 4, "act": 2, "cargo": "bbibbib", "goal": 4, "s2": 6,
		"truck": {"x": 940, "amp": 100, "period": 5.0, "wall": 56}, "guide": 0.5, "wind": -80,
		"movers": [{"type": "ski_lift", "ax": 380, "ay": 210, "bx": 860, "by": 300, "chairs": 2, "speed": 110}]},
	{"world": 4, "act": 2, "cargo": "bibbibib", "goal": 5, "s2": 7,
		"truck": {"x": 1010, "amp": 0, "period": 4.0, "wall": 56, "icy": true}, "guide": 0.4,
		"height_limit": 170,
		"movers": [{"type": "ski_lift", "ax": 380, "ay": 170, "bx": 880, "by": 270, "chairs": 3, "speed": 100}],
		"intro": {"title": "SNOW BOSS", "text": "Bank off the chairs into an icy truck under a low rock."}},
	# ---------------- FREIGHT YARD, Act II (IDs 66-70) ----------------
	{"world": 5, "act": 2, "cargo": "bbbbbb", "goal": 3, "s2": 5,
		"truck": {"x": 1000, "amp": 0, "period": 4.0, "wall": 52}, "guide": 0.8,
		"movers": [{"type": "conveyor", "x0": 420, "x1": 760, "y": 440, "speed": 160}],
		"intro": {"title": "CONVEYOR", "text": "The belt carries cargo toward the truck. Drop it on gently."}},
	{"world": 5, "act": 2, "cargo": "bbbbbbb", "goal": 4, "s2": 6,
		"truck": {"x": 900, "amp": 0, "period": 4.0, "vehicle": "flatbed"}, "guide": 0.7,
		"intro": {"title": "FLATBED", "text": "No sides at all. Stack it neatly and keep it balanced."}},
	{"world": 5, "act": 2, "cargo": "bbbbbbb", "goal": 4, "s2": 6,
		"trucks": [{"x": 0, "vehicle": "flatcar", "start": 1250, "speed": -45, "exit": 420, "once": true},
			{"x": 0, "vehicle": "flatcar", "start": 1500, "speed": -45, "exit": 420, "once": true}],
		"guide": 0.6,
		"intro": {"title": "FLATCARS", "text": "The train rolls by. Fill each car as it passes."}},
	{"world": 5, "act": 2, "cargo": "bcbbcbb", "goal": 4, "s2": 6,
		"truck": {"x": 980, "amp": 0, "period": 4.0, "vehicle": "flatbed"}, "guide": 0.5,
		"movers": [{"type": "bus", "kind": "train", "period": 420, "speed": 10.0},
			{"type": "conveyor", "x0": 420, "x1": 700, "y": 440, "speed": 150}]},
	{"world": 5, "act": 2, "cargo": "bbcbbcbbb", "goal": 4, "s2": 6,
		"trucks": [{"x": 0, "vehicle": "flatcar", "start": 1100, "speed": -40, "exit": 420, "once": true},
			{"x": 0, "vehicle": "flatcar", "start": 1350, "speed": -40, "exit": 420, "once": true},
			{"x": 0, "vehicle": "flatcar", "start": 1600, "speed": -40, "exit": 420, "once": true}],
		"guide": 0.4,
		"movers": [{"type": "bus", "kind": "train", "period": 360, "speed": 12.0, "phase": 150}],
		"intro": {"title": "YARD BOSS", "text": "Load the passing flatcars while freight trains cut across."}},
	# ---------------- SKY PORT (IDs 71-80) ----------------
	{"world": 6, "cargo": "bbbbb", "goal": 2, "need": 2, "throw_stars": [2, 3],
		"truck": {"x": 880, "vehicle": "heli", "y": 165, "cable": 300, "swing": 8}, "guide": 0.8,
		"intro": {"title": "HELICOPTER", "text": "Drop cargo into the hanging net. It swings: time your throw!"}},
	{"world": 6, "cargo": "bbbbbb", "goal": 3, "need": 3, "throw_stars": [3, 5],
		"truck": {"x": 900, "vehicle": "heli", "y": 165, "cable": 300, "swing": 14}, "guide": 0.7},
	{"world": 6, "cargo": "bbcbbb", "goal": 3, "need": 3, "throw_stars": [3, 5],
		"truck": {"x": 920, "vehicle": "heli", "y": 175, "cable": 300, "swing": 12,
			"bob": 30, "bob_period": 360}, "guide": 0.6,
		"intro": {"title": "BOBBING", "text": "The pilot can't hold still. Watch the net rise and fall."}},
	{"world": 6, "cargo": "bbbbbb", "goal": 3, "need": 3, "throw_stars": [4, 6],
		"truck": {"x": 900, "vehicle": "heli", "y": 165, "cable": 300, "swing": 12}, "guide": 0.5,
		"wind": -90},
	{"world": 6, "cargo": "bcbbcbb", "goal": 3, "need": 3, "throw_stars": [4, 6],
		"truck": {"x": 880, "vehicle": "heli", "y": 165, "cable": 300, "swing": 10,
			"drift": 120, "drift_period": 720}, "guide": 0.5,
		"intro": {"title": "DRIFTING", "text": "Now it drifts across the pad too. Lead the net."}},
	{"world": 6, "cargo": "bbbbbb", "goal": 3, "need": 3, "throw_stars": [3, 5],
		"truck": {"x": 960, "vehicle": "balloon", "y": 470, "rise": 60, "rise_period": 360}, "guide": 0.7,
		"intro": {"title": "HOT-AIR BALLOON", "text": "The basket rises and sinks. Throw under the balloon, not over it!"}},
	{"world": 6, "cargo": "bbbcbbb", "goal": 3, "need": 3, "throw_stars": [4, 6],
		"truck": {"x": 980, "vehicle": "balloon", "y": 460, "rise": 70, "rise_period": 360, "sway": 60, "sway_period": 720},
		"guide": 0.5, "wind": 80},
	{"world": 6, "cargo": "bbbbbbbb", "goal": 4, "need": 4, "throw_stars": [4, 6],
		"trucks": [{"x": 630, "vehicle": "heli", "y": 155, "cable": 300, "swing": 12},
			{"x": 1090, "vehicle": "heli", "y": 185, "cable": 300, "swing": 12, "phase": 90}],
		"guide": 0.5,
		"intro": {"title": "TWO HELICOPTERS", "text": "Two nets, swinging out of step. Fill both!"}},
	{"world": 6, "cargo": "bbcbbcbb", "goal": 4, "need": 4, "throw_stars": [5, 7],
		"trucks": [{"x": 1080, "vehicle": "balloon", "y": 470, "rise": 60, "rise_period": 360},
			{"x": 700, "vehicle": "heli", "y": 175, "cable": 300, "swing": 12, "bob": 24, "bob_period": 360}],
		"guide": 0.4},
	{"world": 6, "cargo": "bbcbbcbbb", "goal": 4, "need": 4, "throw_stars": [5, 7],
		"truck": {"x": 900, "vehicle": "heli", "y": 165, "cable": 300, "swing": 14,
			"drift": 100, "drift_period": 720, "bob": 20, "bob_period": 360}, "guide": 0.4, "wind": -70,
		"intro": {"title": "SKY BOSS", "text": "Drifting, swinging, bobbing, in a crosswind. Every throw counts."}},
	# ---------------- DOWNTOWN (IDs 81-90) ----------------
	{"world": 7, "cargo": "mmmmm", "goal": 3, "s2": 4,
		"truck": {"x": 820, "amp": 0, "period": 4.0, "vehicle": "mailvan"}, "guide": 0.8,
		"intro": {"title": "MAIL VAN", "text": "Parcels go through the slot in the back door. Throw flat!", "icon": "parcel"}},
	{"world": 7, "cargo": "bbbbbb", "goal": 3, "s2": 5,
		"truck": {"x": 940, "amp": 0, "period": 4.0, "vehicle": "garbage"}, "guide": 0.7,
		"movers": [{"type": "bus", "period": 400, "speed": 9.0}]},
	{"world": 7, "cargo": "bbb", "goal": 2, "s2": 3,
		"truck": {"x": 860, "amp": 0, "period": 4.0, "vehicle": "foodtruck"}, "guide": 0.7,
		"intro": {"title": "FOOD TRUCK", "text": "In through the serving window: under the awning, over the counter."}},
	{"world": 7, "cargo": "mmmmmm", "goal": 3, "s2": 5,
		"truck": {"x": 880, "amp": 0, "period": 4.0, "vehicle": "mailvan"}, "guide": 0.6,
		"movers": [{"type": "garage_door", "x": 540, "top": 330, "period": 240, "open": 130}]},
	{"world": 7, "cargo": "bbbb", "goal": 2, "s2": 3,
		"truck": {"x": 860, "amp": 0, "period": 4.0, "vehicle": "foodtruck"}, "guide": 0.5,
		"movers": [{"type": "bus", "period": 420, "speed": 9.0}]},
	{"world": 7, "cargo": "mmmmmm", "goal": 3, "s2": 5,
		"truck": {"x": 860, "amp": 90, "period": 5.0, "vehicle": "mailvan"}, "guide": 0.5,
		"intro": {"title": "ON THE ROUND", "text": "The mail van won't stop for you. Lead your throw."}},
	{"world": 7, "cargo": "bbbbbbb", "goal": 4, "s2": 6,
		"truck": {"x": 900, "amp": 80, "period": 5.0, "vehicle": "garbage"}, "guide": 0.5, "wind": -60},
	{"world": 7, "cargo": "bbbbb", "goal": 2, "s2": 3,
		"truck": {"x": 860, "amp": 0, "period": 4.0, "vehicle": "foodtruck"}, "guide": 0.4, "wind": -50},
	{"world": 7, "cargo": "mmmmmmm", "goal": 4, "s2": 6,
		"truck": {"x": 860, "amp": 0, "period": 4.0, "vehicle": "mailvan"}, "guide": 0.4, "wind": 50,
		"movers": [{"type": "bus", "period": 420, "speed": 9.0}]},
	{"world": 7, "cargo": "mbmbmbm", "goal": 3, "s2": 4,
		"trucks": [{"x": 540, "amp": 0, "period": 4.0, "vehicle": "mailvan"},
			{"x": 960, "amp": 0, "period": 4.0, "vehicle": "foodtruck"}],
		"guide": 0.4,
		"intro": {"title": "DOWNTOWN BOSS", "text": "Parcels through the slot, boxes through the window. Pick the right one!"}},
	# ---------------- CONSTRUCTION (IDs 91-100) ----------------
	{"world": 8, "cargo": "bbbbbb", "goal": 3, "s2": 5,
		"truck": {"x": 980, "amp": 0, "period": 4.0, "wall": 52}, "guide": 0.8,
		"movers": [{"type": "tower_crane", "x": 660, "y": 125, "length": 135, "swing": 14, "period": 240, "slide": 90, "slide_period": 480}],
		"intro": {"title": "TOWER CRANE", "text": "The beam swings and slides along the jib. Wait for your gap."}},
	{"world": 8, "cargo": "cbcbbc", "goal": 3, "s2": 5,
		"truck": {"x": 940, "amp": 0, "period": 4.0, "vehicle": "dump", "tilt": 8}, "guide": 0.7,
		"movers": [{"type": "tower_crane", "x": 640, "y": 125, "length": 115, "swing": 12, "period": 240, "slide": 80, "slide_period": 480}]},
	{"world": 8, "cargo": "bbbbbbb", "goal": 4, "s2": 6,
		"truck": {"x": 980, "amp": 0, "period": 4.0, "vehicle": "flatbed"}, "guide": 0.6,
		"blocks": [[360, 320, 400, 36]],
		"pads": [[560, 579, 4, 1.1]],
		"movers": [{"type": "forklift", "x0": 330, "x1": 480, "period": 340, "forks": 80}]},
	{"world": 8, "cargo": "bcbcbb", "goal": 3, "s2": 5,
		"truck": {"x": 1000, "amp": 0, "period": 4.0, "vehicle": "dump", "tilt": 8}, "guide": 0.6,
		"movers": [{"type": "conveyor", "x0": 420, "x1": 760, "y": 440, "speed": 150}]},
	{"world": 8, "cargo": "bbbbbbb", "goal": 4, "s2": 6,
		"truck": {"x": 960, "amp": 0, "period": 4.0, "vehicle": "flatbed"}, "guide": 0.5,
		"movers": [{"type": "tower_crane", "x": 680, "y": 125, "length": 125, "swing": 16, "period": 220, "slide": 110, "slide_period": 440}]},
	{"world": 8, "cargo": "bbcbbcb", "goal": 4, "s2": 6,
		"truck": {"x": 1000, "amp": 0, "period": 4.0, "wall": 56}, "guide": 0.5,
		"blocks": [[380, 320, 420, 36]],
		"pads": [[560, 579, 4, 1.1]],
		"movers": [{"type": "forklift", "x0": 340, "x1": 470, "period": 280, "forks": 80},
			{"type": "conveyor", "x0": 640, "x1": 820, "y": 430, "speed": 140}]},
	{"world": 8, "cargo": "ccbcbbc", "goal": 4, "s2": 6,
		"truck": {"x": 960, "amp": 0, "period": 4.0, "vehicle": "dump", "tilt": 10}, "guide": 0.5, "wind": -70,
		"movers": [{"type": "tower_crane", "x": 640, "y": 125, "length": 115, "swing": 14, "period": 240, "slide": 90, "slide_period": 480}]},
	{"world": 8, "cargo": "bbbbbbbb", "goal": 3, "s2": 4,
		"truck": {"x": 970, "amp": 0, "period": 4.0, "vehicle": "flatbed"}, "guide": 0.4, "wind": 60,
		"movers": [{"type": "tower_crane", "x": 660, "y": 125, "length": 125, "swing": 14, "period": 240, "slide": 100, "slide_period": 480}]},
	{"world": 8, "cargo": "bbcbbbcb", "goal": 5, "s2": 7,
		"truck": {"x": 1000, "amp": 0, "period": 4.0, "vehicle": "flatbed"}, "guide": 0.4,
		"movers": [{"type": "conveyor", "x0": 420, "x1": 700, "y": 440, "speed": 150},
			{"type": "tower_crane", "x": 760, "y": 125, "length": 115, "swing": 12, "period": 240, "slide": 80, "slide_period": 480}]},
	{"world": 8, "cargo": "bbcbbcbbb", "goal": 5, "s2": 7,
		"truck": {"x": 990, "amp": 0, "period": 4.0, "vehicle": "flatbed"}, "guide": 0.4,
		"blocks": [[360, 320, 400, 36]],
		"pads": [[560, 579, 4, 1.1]],
		"movers": [{"type": "forklift", "x0": 330, "x1": 480, "period": 480, "forks": 80},
			{"type": "tower_crane", "x": 720, "y": 125, "length": 105, "swing": 8, "period": 240, "slide": 80, "slide_period": 480, "phase": 60}],
		"intro": {"title": "SITE BOSS", "text": "Stack the flatbed while the forklift patrols and the beam swings."}},
]

const LETTER = {"b": "box", "c": "crate", "r": "barrel", "f": "fragile",
	"i": "ice", "t": "tire", "p": "plank", "g": "canister", "m": "parcel"}


static func count() -> int:
	return DATA.size()


static func get_level(i: int) -> Dictionary:
	return DATA[clampi(i, 0, DATA.size() - 1)]


static func cargo_list(i: int) -> Array:
	var out: Array = []
	for ch in get_level(i).cargo:
		out.append(LETTER[ch])
	return out


static func stars_for(i: int, delivered: int, thrown := -1) -> int:
	var lv = get_level(i)
	if lv.has("need"):
		# few-throws levels (e.g. V1 motorcycle): load `need`; stars count the throws it took
		if delivered < lv.need:
			return 0
		var ts: Array = lv.get("throw_stars", [lv.need, lv.need + 1])
		if thrown >= 0 and thrown <= ts[0]:
			return 3
		if thrown >= 0 and thrown <= ts[1]:
			return 2
		return 1
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


# ------------------------------------------------------------------ play order + unlocks
static var _order: Array = []


## Level IDs in play order.
static func order() -> Array:
	if _order.is_empty():
		for w in WORLD_ORDER:
			for act in [1, 2]:
				for i in DATA.size():
					if DATA[i].world == w and DATA[i].get("act", 1) == act:
						_order.append(i)
	return _order


## The level number players see (position in play order, from 1).
static func number_of(i: int) -> int:
	return order().find(i) + 1


static func id_of_number(n: int) -> int:
	return order()[clampi(n - 1, 0, order().size() - 1)]


static func next_of(i: int) -> int:
	var k = order().find(i)
	return order()[k + 1] if k >= 0 and k + 1 < order().size() else -1


static func act_of(i: int) -> int:
	return DATA[i].get("act", 1)


## Levels of a world in play order (Act I then Act II).
static func levels_in_world_ordered(w: int) -> Array:
	var out: Array = []
	for i in order():
		if DATA[i].world == w:
			out.append(i)
	return out


static func unlocked(i: int) -> bool:
	var w: int = DATA[i].world
	var act = act_of(i)
	var same: Array = []
	for j in levels_in_world_ordered(w):
		if act_of(j) == act:
			same.append(j)
	var k = same.find(i)
	if k > 0:
		return SaveData.stars(same[k - 1]) > 0  # chain within an act
	if act == 2:
		# Act II opens once this world's Act I is complete
		for j in levels_in_world_ordered(w):
			if act_of(j) == 1 and SaveData.stars(j) == 0:
				return false
		return true
	# first level of a world's Act I
	var wk = WORLD_ORDER.find(w)
	if wk <= 0:
		return true
	if WORLDS[w].has("unlock_stars"):
		return SaveData.total_stars() >= WORLDS[w].unlock_stars
	if DATA[i].world <= 5 and i > 0 and DATA[i - 1].get("act", 1) == 1:
		return SaveData.stars(i - 1) > 0  # the original 40 levels: one chain, as before
	for j in levels_in_world_ordered(WORLD_ORDER[wk - 1]):
		if act_of(j) == 1 and SaveData.stars(j) == 0:
			return false
	return true


static func world_of(i: int) -> Dictionary:
	return WORLDS[get_level(i).world]
