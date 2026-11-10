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
	return out
