class_name ArtAssets
extends RefCounted
## Central swap-in points for v3 art. Each path is a file drop: if the resource
## is missing, callers keep the current v2 / code-drawn look.
##
## Palette B is on: the V0 truck body is fire-engine #DC2638 / shade #A51A2B.
## Flip this to false to restore the previous coral #E4572E / #B83F1F.

## true = palette B fire-engine #DC2638 / #A51A2B. false = previous #E4572E / #B83F1F.
const USE_PALETTE_B := true

# ---- paths (720p design px unless noted) ---------------------------------
const TRUCK_V0 := "res://art/v3/truck/truck_v0.png"
const TOWN_BG := "res://art/v3/bg/bg_town.png"
const CLOUDS := "res://art/v3/bg/clouds.png"
const DOCK_WAREHOUSE := "res://art/v3/dock/warehouse.png"
const DOCK_FACE := "res://art/v3/dock/dock_face.png"
const DOCK_BEACON := "res://art/v3/dock/beacon.png"
const DOCK_BELT := [
	"res://art/v3/dock/belt_0.png",
	"res://art/v3/dock/belt_1.png",
	"res://art/v3/dock/belt_2.png",
]
const CARGO_DIR := "res://art/v3/cargo/"
const TITLE_FONT_CANDIDATES := [
	"res://art/v3/font/title.ttf",
	"res://art/v3/font/LilitaOne-Regular.ttf",
	"res://art/v3/font/TitanOne-Regular.ttf",
]
const WORDMARK := "res://art/v3/brand/wordmark.png"
const FX_ATLAS := "res://art/v3/fx/fx_atlas.png"
# ---- Phase 2: cargo C5-C9 extras, stars, icons, world icons -----------------
# File names follow FF Visuals' phase2 handoff (art/v3/ui/*, art/v3/ui/world/*).
## Optional queue thumbnail per cargo kind (square 32x32 or 64x64).
## Missing = the HUD queue uses the cargo texture itself (today's look).
const CARGO_THUMB_DIR := "res://art/v3/cargo/thumb/"
## PLANK (C7) is drawn as a 3-slice when the v3 file is present: PLANK_CAP design px at
## each end keep their shape and only the middle stretches to the per-level length.
## Collision stays TYPES.plank.size / level.plank.length; this is visual only.
const PLANK_NATIVE := Vector2(150, 24)
const PLANK_CAP := 16.0
const UI_DIR := "res://art/v3/ui/"
## U3 stars. Big (96 px, also 64 / 128 accepted): results card and the level-select
## header total. Small (30 px or 2x 60): HUD LOADED bar and level tiles. A missing small
## file falls back to the big one; a missing "off" star falls back to the tinted "on"
## star, and a missing "on" star to v2 star_gold.png (today's look).
const STAR_ON := "res://art/v3/ui/star_on.png"
const STAR_OFF := "res://art/v3/ui/star_off.png"
const STAR_ON_S := "res://art/v3/ui/star_on_s.png"
const STAR_OFF_S := "res://art/v3/ui/star_off_s.png"
## HUD bar star size: v2 = 26 px. With a v3 small star the HUD draws it at its own
## 34 px (21 px at 800x450, vs 16 for v2) with no tint so they read at 800x450.
const HUD_STAR_SIZE := 26.0
const HUD_STAR_SIZE_V3 := 34.0
## U4 icons (white glyph art). Missing = v2 Kenney icon. Missing left arrow = the
## right arrow (v3 or v2) mirrored, as today.
const ICON_PADLOCK := "res://art/v3/ui/padlock.png"
const ICON_ARROW_RIGHT := "res://art/v3/ui/arrow_right.png"
const ICON_ARROW_LEFT := "res://art/v3/ui/arrow_left.png"
const ICON_PAUSE := "res://art/v3/ui/pause.png"
const ICON_SOUND_ON := "res://art/v3/ui/sound_on.png"
const ICON_SOUND_OFF := "res://art/v3/ui/sound_off.png"
const ICON_HOME := "res://art/v3/ui/home.png"  # tools/art/make_ui.py
## V8 world icons (level select, 96x56 box, file 96x56 or 2x 192x112). Per-world file
## (world name lower-case, spaces -> _) wins, then the shared truck.png, then the
## code-drawn vehicle (today).
const WORLD_ICON_DIR := "res://art/v3/ui/world/"
const WORLD_ICON_SHARED := "res://art/v3/ui/world/truck.png"
const WORLD_ICON_SIZE := Vector2(96, 56)
## v3 icons draw bigger in the level-select header (120x70 at 720p = 75x44 at 800x450);
## the code-drawn fallback keeps its 96x56 box.
const WORLD_ICON_SIZE_V3 := Vector2(120, 70)

# ---- Phase 3: skies ------------------------------------------------------------
## Full-frame world background, 1280x720 (or 2x), top-left at (0, 0), z -20, under the
## clouds: art/v3/bg/bg_<world>.png. S1 town, S2 woods, S3 desert, S6 freight_yard,
## S7 downtown, plus harbor, snow, construction and sky_port (tools/art/make_bg.py).
## For a code-drawn backdrop world (Freight Yard, Downtown) the file
## replaces the whole backdrop. Missing = v2 Kenney sprite / code backdrop (today).
const BG_DIR := "res://art/v3/bg/"
const PHASE3_BG_WORLDS := ["WOODS", "DESERT", "FREIGHT YARD", "DOWNTOWN", "HARBOR", "SNOW", "CONSTRUCTION", "SKY PORT"]

## Truck sprite slots at 720p (or 2x):
##   470 x 190, origin (157, 112) — crop from the cab roof
##   470 x 198, origin (157, 120) — 8 px taller so the bulkhead reaches FRONT_H
## Detected from the texture height (1x or 2x). Width and origin.x stay 470 / 157,
## so the front bumper is still 313 px right of the bed centre.
const TRUCK_W := 470.0
const TRUCK_H_190 := 190.0
const TRUCK_H_198 := 198.0
const TRUCK_ORIGIN_190 := Vector2(157, 112)
const TRUCK_ORIGIN_198 := Vector2(157, 120)
## Default (190-slot) origin, kept so older comments/docs still resolve.
const TRUCK_ORIGIN := TRUCK_ORIGIN_190
const TRUCK_H := TRUCK_H_190


static func exists(path: String) -> bool:
	return path != "" and ResourceLoader.exists(path)


static func try_texture(path: String) -> Texture2D:
	if not exists(path):
		return null
	var res = load(path)
	return res if res is Texture2D else null


static func try_font(path: String) -> Font:
	if not exists(path):
		return null
	var res = load(path)
	return res if res is Font else null


static func truck_body() -> Color:
	return ArtPalette.TRUCK_RED_B if USE_PALETTE_B else ArtPalette.TRUCK_RED_CURRENT


static func truck_shade() -> Color:
	return ArtPalette.TRUCK_SHADE_B if USE_PALETTE_B else ArtPalette.TRUCK_SHADE_CURRENT


static func truck_palette() -> Array:
	return [truck_body(), truck_shade()]


static func truck_texture() -> Texture2D:
	return try_texture(TRUCK_V0)


## Design-pixel size of the truck slot (width always 470).
static func truck_design_size(tex: Texture2D) -> Vector2:
	var sx := TRUCK_W / float(tex.get_width())
	return Vector2(TRUCK_W, float(tex.get_height()) * sx)


## Pivot in design pixels, chosen by the slot height (190 or 198, 1x or 2x).
static func truck_origin_for(tex: Texture2D) -> Vector2:
	var h := truck_design_size(tex).y
	if abs(h - TRUCK_H_198) < 1.0:
		return TRUCK_ORIGIN_198
	return TRUCK_ORIGIN_190


## Right edge of the truck slot, in design px relative to the bed-floor centre.
## Both slots are 470 wide with origin.x 157, so this is 313 — same as Truck.FRONT_EXTENT.
static func truck_front_extent(tex: Texture2D = null) -> float:
	var t: Texture2D = tex if tex else truck_texture()
	var origin := TRUCK_ORIGIN_190
	if t:
		origin = truck_origin_for(t)
	return TRUCK_W - origin.x


static func town_background() -> Texture2D:
	return try_texture(TOWN_BG)


static func clouds_texture() -> Texture2D:
	return try_texture(CLOUDS)


static func warehouse_texture() -> Texture2D:
	return try_texture(DOCK_WAREHOUSE)


static func dock_face_texture() -> Texture2D:
	return try_texture(DOCK_FACE)


static func beacon_texture() -> Texture2D:
	return try_texture(DOCK_BEACON)


static func belt_texture(i: int) -> Texture2D:
	if i < 0 or i >= DOCK_BELT.size():
		return null
	return try_texture(DOCK_BELT[i])


static func cargo_texture(kind: String) -> Texture2D:
	return try_texture(CARGO_DIR + kind + ".png")


static func cargo_thumb(kind: String) -> Texture2D:
	return try_texture(CARGO_THUMB_DIR + kind + ".png")


static func kind_is_v3(kind: String) -> bool:
	return exists(CARGO_DIR + kind + ".png")


## Visual-only 3-slice for the v3 plank. Returns null (use a plain stretched Sprite2D)
## when there is no v3 plank, so the v2 look and node tree stay as they were.
static func plank_skin(length: float, height: float) -> NinePatchRect:
	var tex := cargo_texture("plank")
	if tex == null:
		return null
	var kx := float(tex.get_width()) / PLANK_NATIVE.x
	var ky := float(tex.get_height()) / PLANK_NATIVE.y
	var np := NinePatchRect.new()
	np.texture = tex
	np.patch_margin_left = int(round(PLANK_CAP * kx))
	np.patch_margin_right = int(round(PLANK_CAP * kx))
	np.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	np.size = Vector2(length * kx, height * ky)
	np.scale = Vector2(1.0 / kx, 1.0 / ky)
	np.position = -Vector2(length, height) * 0.5
	return np


## U3 star art: on/off, big (96) or small (30, falls back to big). null = no v3 file.
static func star_texture(on: bool, small := false) -> Texture2D:
	if small:
		var s := try_texture(STAR_ON_S if on else STAR_OFF_S)
		if s:
			return s
	return try_texture(STAR_ON if on else STAR_OFF)


static func padlock_icon() -> Texture2D:
	return try_texture(ICON_PADLOCK)


static func arrow_icon(left: bool) -> Texture2D:
	return try_texture(ICON_ARROW_LEFT if left else ICON_ARROW_RIGHT)


## v2 icon path -> v3 file if dropped (pause, sound on/off, home).
const V2_ICON_TO_V3 := {
	"res://art/v2/icons/pause.png": ICON_PAUSE,
	"res://art/v2/icons/audioOn.png": ICON_SOUND_ON,
	"res://art/v2/icons/audioOff.png": ICON_SOUND_OFF,
	"res://art/v2/icons/home.png": ICON_HOME,
}


static func hud_icon(v2_path: String) -> Texture2D:
	var t := try_texture(V2_ICON_TO_V3.get(v2_path, ""))
	return t if t else load(v2_path)


## "FREIGHT YARD" -> "freight_yard"
static func world_key(world_name: String) -> String:
	return world_name.to_lower().replace(" ", "_")


static func world_icon(world_name: String) -> Texture2D:
	if world_name != "":
		var t := try_texture(WORLD_ICON_DIR + world_key(world_name) + ".png")
		if t:
			return t
	return try_texture(WORLD_ICON_SHARED)


## V8 by world index (Levels.WORLDS); -1 = only the shared truck icon.
static func world_icon_for(world: int) -> Texture2D:
	if world >= 0 and world < Levels.WORLDS.size():
		return world_icon(Levels.WORLDS[world].name)
	return world_icon("")


static func world_background_path(world_name: String) -> String:
	return BG_DIR + "bg_" + world_key(world_name) + ".png" if world_name != "" else ""


static func world_background(world_name: String) -> Texture2D:
	return try_texture(world_background_path(world_name))


static func world_icon_keys() -> PackedStringArray:
	var out: PackedStringArray = []
	for w in Levels.WORLDS:
		out.append(world_key(w.name))
	return out


## Every Phase 2 / 3 slot path (tests and docs).
static func phase23_paths() -> PackedStringArray:
	var out: PackedStringArray = []
	for k in ["ice", "tire", "plank", "canister", "parcel"]:
		out.append(CARGO_DIR + k + ".png")
	for k in ["box", "crate", "barrel", "fragile", "ice", "tire", "plank", "canister", "parcel"]:
		out.append(CARGO_THUMB_DIR + k + ".png")
	out.append_array([STAR_ON, STAR_OFF, STAR_ON_S, STAR_OFF_S, ICON_PADLOCK, ICON_ARROW_RIGHT, ICON_ARROW_LEFT,
		ICON_PAUSE, ICON_SOUND_ON, ICON_SOUND_OFF, WORLD_ICON_SHARED])
	for k in world_icon_keys():
		out.append(WORLD_ICON_DIR + k + ".png")
	for w in PHASE3_BG_WORLDS:
		out.append(world_background_path(w))
	return out


static func title_font() -> Font:
	for p in TITLE_FONT_CANDIDATES:
		var f = try_font(p)
		if f:
			return f
	return null


static func wordmark_texture() -> Texture2D:
	return try_texture(WORDMARK)


static func all_v3_paths() -> PackedStringArray:
	var out: PackedStringArray = [
		TRUCK_V0, TOWN_BG, CLOUDS, DOCK_WAREHOUSE, DOCK_FACE, DOCK_BEACON,
		WORDMARK, FX_ATLAS,
	]
	out.append_array(DOCK_BELT)
	for k in ["box", "crate", "barrel", "fragile", "ice", "tire", "plank", "canister", "parcel"]:
		out.append(CARGO_DIR + k + ".png")
	out.append_array(TITLE_FONT_CANDIDATES)
	for p in phase23_paths():
		if not p in out:
			out.append(p)
	return out
