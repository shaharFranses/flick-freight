extends SceneTree
## Assert the v3 PNG swap-in fallback: with no raster drops present, those hooks
## return null and cargo collision sizes stay unchanged. Palette B and the
## Lilita One title font are already on (not part of the missing-file fallback).
##   godot --headless -s res://tools/art_fallback_test.gd

const CARGO_SIZES = {
	"box": Vector2(60, 60),
	"crate": Vector2(62, 62),
	"barrel": Vector2(46, 64),
	"fragile": Vector2(58, 58),
	"ice": Vector2(58, 58),
	"tire": Vector2(56, 56),
	"plank": Vector2(150, 24),
	"canister": Vector2(44, 58),
	"parcel": Vector2(46, 30),
}


func _init():
	var bad := 0
	if not ArtAssets.USE_PALETTE_B:
		print("ART FALLBACK: USE_PALETTE_B is off; expected palette B")
		bad += 1
	var pal: Array = ArtAssets.truck_palette()
	if not pal[0].is_equal_approx(Color("#DC2638")) or not pal[1].is_equal_approx(Color("#A51A2B")):
		print("ART FALLBACK: palette is %s, not #DC2638 / #A51A2B" % pal)
		bad += 1
	if not Truck.resolved_palette(0)[0].is_equal_approx(Color("#DC2638")):
		print("ART FALLBACK: Truck.resolved_palette is not palette B")
		bad += 1
	if ArtAssets.truck_texture() != null:
		print("ART FALLBACK: truck_v0.png is present; this test expects an empty slot")
		bad += 1
	if ArtAssets.town_background() != null:
		print("ART FALLBACK: bg_town.png is present; this test expects an empty slot")
		bad += 1
	if ArtAssets.clouds_texture() != null:
		print("ART FALLBACK: v3 clouds.png is present; this test expects an empty slot")
		bad += 1
	if ArtAssets.warehouse_texture() != null or ArtAssets.dock_face_texture() != null:
		print("ART FALLBACK: a dock PNG is present; this test expects empty slots")
		bad += 1
	if ArtAssets.beacon_texture() != null or ArtAssets.belt_texture(0) != null:
		print("ART FALLBACK: a belt/beacon PNG is present; this test expects empty slots")
		bad += 1
	if ArtAssets.title_font() == null:
		print("ART FALLBACK: title font (Lilita One) is missing")
		bad += 1
	if ArtAssets.wordmark_texture() != null:
		print("ART FALLBACK: wordmark is present; this test expects an empty slot")
		bad += 1
	# Raster slots should still be empty; the title font is the one shipped v3 file.
	var font_paths: PackedStringArray = ArtAssets.TITLE_FONT_CANDIDATES
	for path in ArtAssets.all_v3_paths():
		if path in font_paths:
			continue
		if ResourceLoader.exists(path):
			print("ART FALLBACK: unexpected v3 resource %s" % path)
			bad += 1
	for kind in CARGO_SIZES:
		if ArtAssets.cargo_texture(kind) != null:
			print("ART FALLBACK: cargo %s v3 PNG is present" % kind)
			bad += 1
		var sz: Vector2 = Cargo.TYPES[kind].size
		if sz != CARGO_SIZES[kind]:
			print("ART FALLBACK: %s size %s != %s" % [kind, sz, CARGO_SIZES[kind]])
			bad += 1
		var tex: Texture2D = Cargo.texture_for(kind)
		if tex == null:
			print("ART FALLBACK: %s has no v2 fallback texture" % kind)
			bad += 1
		var v2: String = Cargo.TYPES[kind].tex
		if not v2.begins_with("res://art/v2/cargo/"):
			print("ART FALLBACK: %s TYPES.tex left v2 (%s)" % [kind, v2])
			bad += 1
	# Town world still points at the v2 sky so a missing drop does not rewrite levels.gd
	var town: Dictionary = Levels.WORLDS[0]
	if town.get("bg", "") != "res://art/v2/bg/bg_town.png":
		print("ART FALLBACK: Town world bg path changed: %s" % town.get("bg"))
		bad += 1
	print("ART FALLBACK CHECK: %d problem(s)" % bad)
	quit(1 if bad else 0)
