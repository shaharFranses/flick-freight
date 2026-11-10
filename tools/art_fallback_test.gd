extends SceneTree
## Assert the v3 swap-in fallback: with no art/v3 files present, every hook
## returns null / the current look, and cargo collision sizes stay unchanged.
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
	if ArtAssets.USE_PALETTE_B:
		print("ART FALLBACK: USE_PALETTE_B is true; default must stay false until assets land")
		bad += 1
	var pal: Array = ArtAssets.truck_palette()
	if not pal[0].is_equal_approx(Color("#E4572E")) or not pal[1].is_equal_approx(Color("#B83F1F")):
		print("ART FALLBACK: default palette is %s, not #E4572E / #B83F1F" % pal)
		bad += 1
	if not Truck.resolved_palette(0)[0].is_equal_approx(Color("#E4572E")):
		print("ART FALLBACK: Truck.resolved_palette is not the current red")
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
	if ArtAssets.title_font() != null:
		print("ART FALLBACK: title font is present; this test expects an empty slot")
		bad += 1
	if ArtAssets.wordmark_texture() != null:
		print("ART FALLBACK: wordmark is present; this test expects an empty slot")
		bad += 1
	for path in ArtAssets.all_v3_paths():
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
