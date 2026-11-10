extends SceneTree
## Assert v3 swap-in behaviour in two modes:
##   empty    — no raster drops: hooks return null and cargo falls back to v2
##   present  — delivered files load at the expected sizes
## Auto-detects from whether art/v3/truck/truck_v0.png (or the Town sky) is there.
## Palette B and the Lilita One title font are always required.
##   godot --headless -s res://tools/art_fallback_test.gd
##   godot --headless -s res://tools/art_fallback_test.gd -- --mode=empty|present|auto
## Phase 2 / 3 slots are checked per file (each slot: missing = old look, present = loaded
## at its size and used by its hook). --p23=empty|present|auto additionally asserts that
## every Phase 2/3 slot is missing / present (auto = no assertion, per-file only).
##   tools/art_p23_dummy.sh   runs this on a scratch copy with dummy files dropped in

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

## Phase 1 cargo that Visuals delivered; the rest must still fall back to v2.
const PHASE1_CARGO = ["box", "crate", "barrel", "fragile"]


func _init():
	var mode := "auto"
	var p23 := "auto"
	for a in OS.get_cmdline_user_args():
		var p = a.trim_prefix("--").split("=")
		if p[0] == "mode" and p.size() > 1:
			mode = p[1]
		if p[0] == "p23" and p.size() > 1:
			p23 = p[1]
	var rasters_present := ArtAssets.truck_texture() != null or ArtAssets.town_background() != null
	if mode == "auto":
		mode = "present" if rasters_present else "empty"
	var bad := 0
	if mode == "present" and not rasters_present:
		print("ART FALLBACK: --mode=present but no v3 rasters are loaded")
		bad += 1
	if mode == "empty" and rasters_present:
		print("ART FALLBACK: --mode=empty but v3 rasters are present (hide them to test fallback)")
		bad += 1

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
	if ArtAssets.title_font() == null:
		print("ART FALLBACK: title font (Lilita One) is missing")
		bad += 1
	if ArtAssets.wordmark_texture() != null:
		print("ART FALLBACK: wordmark is present; this test expects an empty slot")
		bad += 1

	# Collision sizes and the v2 fallback path never change.
	for kind in CARGO_SIZES:
		var sz: Vector2 = Cargo.TYPES[kind].size
		if sz != CARGO_SIZES[kind]:
			print("ART FALLBACK: %s size %s != %s" % [kind, sz, CARGO_SIZES[kind]])
			bad += 1
		var v2: String = Cargo.TYPES[kind].tex
		if not v2.begins_with("res://art/v2/cargo/"):
			print("ART FALLBACK: %s TYPES.tex left v2 (%s)" % [kind, v2])
			bad += 1
		var tex: Texture2D = Cargo.texture_for(kind)
		if tex == null:
			print("ART FALLBACK: %s has no texture" % kind)
			bad += 1
	var town: Dictionary = Levels.WORLDS[0]
	if town.get("bg", "") != "res://art/v2/bg/bg_town.png":
		print("ART FALLBACK: Town world bg path changed: %s" % town.get("bg"))
		bad += 1

	if mode == "present":
		bad += _check_present()
	else:
		bad += _check_empty()
	var p23_bad := _check_phase23(p23)
	bad += p23_bad

	print("ART FALLBACK CHECK: %d problem(s) (mode=%s, p23=%s)" % [bad, mode, p23])
	quit(1 if bad else 0)


func _is_size(tex: Texture2D, allowed: Array) -> bool:
	var got := Vector2i(tex.get_width(), tex.get_height())
	for s in allowed:
		if got == s:
			return true
	return false


func _check_present() -> int:
	var bad := 0
	var truck := ArtAssets.truck_texture()
	if truck == null:
		print("ART PRESENT: truck_v0.png failed to load")
		bad += 1
	elif not _is_size(truck, [Vector2i(470, 190), Vector2i(940, 380), Vector2i(470, 198), Vector2i(940, 396)]):
		print("ART PRESENT: truck_v0.png is %dx%d, expected 470x190 / 470x198 (or 2x)" % [
			truck.get_width(), truck.get_height()])
		bad += 1
	else:
		var origin := ArtAssets.truck_origin_for(truck)
		var expect := ArtAssets.TRUCK_ORIGIN_198 if abs(ArtAssets.truck_design_size(truck).y - 198.0) < 1.0 else ArtAssets.TRUCK_ORIGIN_190
		if origin != expect:
			print("ART PRESENT: truck origin %s != %s" % [origin, expect])
			bad += 1
		if not is_equal_approx(ArtAssets.truck_front_extent(truck), 313.0):
			print("ART PRESENT: truck front extent %.1f != 313" % ArtAssets.truck_front_extent(truck))
			bad += 1
	var town := ArtAssets.town_background()
	if town == null:
		print("ART PRESENT: bg_town.png failed to load")
		bad += 1
	elif not _is_size(town, [Vector2i(1280, 720), Vector2i(2560, 1440)]):
		print("ART PRESENT: bg_town.png is %dx%d, expected 1280x720 (or 2x)" % [
			town.get_width(), town.get_height()])
		bad += 1
	var clouds := ArtAssets.clouds_texture()
	if clouds == null:
		print("ART PRESENT: clouds.png failed to load")
		bad += 1
	elif not _is_size(clouds, [Vector2i(1024, 400)]):
		print("ART PRESENT: clouds.png is %dx%d, expected 1024x400" % [
			clouds.get_width(), clouds.get_height()])
		bad += 1
	var wh := ArtAssets.warehouse_texture()
	if wh == null or not _is_size(wh, [Vector2i(190, 240)]):
		print("ART PRESENT: warehouse.png missing or %s" % (wh.get_size() if wh else "null"))
		bad += 1
	var face := ArtAssets.dock_face_texture()
	if face == null or not _is_size(face, [Vector2i(286, 199)]):
		print("ART PRESENT: dock_face.png missing or %s" % (face.get_size() if face else "null"))
		bad += 1
	var beacon := ArtAssets.beacon_texture()
	if beacon == null or not _is_size(beacon, [Vector2i(63, 63), Vector2i(126, 126)]):
		print("ART PRESENT: beacon.png missing or %s" % (beacon.get_size() if beacon else "null"))
		bad += 1
	for i in 3:
		var b := ArtAssets.belt_texture(i)
		if b == null or not _is_size(b, [Vector2i(63, 63), Vector2i(126, 126)]):
			print("ART PRESENT: belt_%d.png missing or %s" % [i, b.get_size() if b else "null"])
			bad += 1
	for kind in PHASE1_CARGO:
		var tex := ArtAssets.cargo_texture(kind)
		if tex == null:
			print("ART PRESENT: cargo %s failed to load" % kind)
			bad += 1
		elif Vector2(tex.get_width(), tex.get_height()) != CARGO_SIZES[kind]:
			print("ART PRESENT: cargo %s is %dx%d, expected %s" % [
				kind, tex.get_width(), tex.get_height(), CARGO_SIZES[kind]])
			bad += 1
		# texture_for must return the v3 file, not the v2 fallback
		if tex and Cargo.texture_for(kind) != tex:
			print("ART PRESENT: Cargo.texture_for(%s) did not use the v3 texture" % kind)
			bad += 1
	# Phase 2 cargo (C5-C9) is checked per file in _check_phase23().
	return bad


func _check_empty() -> int:
	var bad := 0
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
	var font_paths: PackedStringArray = ArtAssets.TITLE_FONT_CANDIDATES
	var p23_paths: PackedStringArray = ArtAssets.phase23_paths()
	for path in ArtAssets.all_v3_paths():
		if path in font_paths or path in p23_paths:
			continue  # Phase 2/3 slots: per-file in _check_phase23()
		if ResourceLoader.exists(path):
			print("ART FALLBACK: unexpected v3 resource %s" % path)
			bad += 1
	for kind in PHASE1_CARGO:
		if ArtAssets.cargo_texture(kind) != null:
			print("ART FALLBACK: cargo %s v3 PNG is present" % kind)
			bad += 1
	return bad


# ============================================================== Phase 2 / 3
## Allowed pixel sizes per slot (1x and exact 2x design px).
const P2_CARGO = ["ice", "tire", "plank", "canister", "parcel"]
const SQ_STAR = [Vector2i(64, 64), Vector2i(96, 96), Vector2i(128, 128)]
const SQ_STAR_S = [Vector2i(30, 30), Vector2i(60, 60)]
const SQ_THUMB = [Vector2i(32, 32), Vector2i(64, 64)]
const SQ_LOCK = [Vector2i(48, 48), Vector2i(96, 96)]
const SQ_ARROW = [Vector2i(44, 44), Vector2i(88, 88)]
const SQ_HUD_ICON = [Vector2i(40, 40), Vector2i(80, 80)]
const WORLD_ICON = [Vector2i(96, 56), Vector2i(192, 112)]
const SKY = [Vector2i(1280, 720), Vector2i(2560, 1440)]
const PLANK_TEST_LENGTH := 220.0


class FakeGame:
	var level := {"plank": {"length": PLANK_TEST_LENGTH, "spin": 1.8}}


func _sizes_of(v: Vector2) -> Array:
	return [Vector2i(v), Vector2i(v * 2.0)]


## One slot: present -> loads at an allowed size; missing -> resolver returns null.
func _slot(path: String, got: Texture2D, allowed: Array, present: Array, missing: Array) -> int:
	if ResourceLoader.exists(path):
		present.append(path)
		if got == null:
			print("ART P23: %s exists but its hook returned null" % path)
			return 1
		if not _is_size(got, allowed):
			print("ART P23: %s is %dx%d, expected one of %s" % [path, got.get_width(), got.get_height(), allowed])
			return 1
		return 0
	missing.append(path)
	if got != null:
		print("ART P23: %s missing but its hook returned a texture" % path)
		return 1
	return 0


func _shape_size(c: Cargo) -> Vector2:
	for ch in c.get_children():
		if ch is CollisionShape2D:
			if ch.shape is RectangleShape2D:
				return ch.shape.size
			if ch.shape is CircleShape2D:
				return Vector2(ch.shape.radius * 2.0, ch.shape.radius * 2.0)
	return Vector2.ZERO


func _check_phase23(expect: String) -> int:
	var bad := 0
	var present: Array = []
	var missing: Array = []
	# ---- (a) cargo C5-C9 + queue thumbs. Collision is always TYPES size.
	for kind in P2_CARGO:
		var path: String = ArtAssets.CARGO_DIR + kind + ".png"
		var v3 := ArtAssets.cargo_texture(kind)
		bad += _slot(path, v3, _sizes_of(CARGO_SIZES[kind]), present, missing)
		var used := Cargo.texture_for(kind)
		if v3 and used != v3:
			print("ART P23: Cargo.texture_for(%s) ignored the v3 file" % kind)
			bad += 1
		if v3 == null and used.resource_path != Cargo.TYPES[kind].tex:
			print("ART P23: %s fallback is %s, not v2" % [kind, used.resource_path])
			bad += 1
		var c := Cargo.new()
		c.setup(kind, FakeGame.new() if kind == "plank" else null)
		var want: Vector2 = CARGO_SIZES[kind]
		if kind == "plank":
			want = Vector2(PLANK_TEST_LENGTH, 24)
		if _shape_size(c) != want:
			print("ART P23: %s collision %s != %s" % [kind, _shape_size(c), want])
			bad += 1
		if not is_equal_approx(c.mass, Cargo.TYPES[kind].mass):
			print("ART P23: %s mass changed" % kind)
			bad += 1
		if kind == "plank" and v3:
			# 3-slice: no Sprite2D, skin covers exactly the collision rect
			if c.plank_skin == null or c.sprite != null:
				print("ART P23: v3 plank is not drawn as a 3-slice")
				bad += 1
			else:
				var vis: Vector2 = c.plank_skin.size * c.plank_skin.scale
				if not vis.is_equal_approx(want) or not c.plank_skin.position.is_equal_approx(-want * 0.5):
					print("ART P23: plank skin %s at %s, expected %s centred" % [vis, c.plank_skin.position, want])
					bad += 1
				var kx := float(v3.get_width()) / ArtAssets.PLANK_NATIVE.x
				if c.plank_skin.patch_margin_left != int(round(ArtAssets.PLANK_CAP * kx)):
					print("ART P23: plank cap margin %d" % c.plank_skin.patch_margin_left)
					bad += 1
		else:
			# old look: one Sprite2D scaled to the collision rect
			if c.sprite == null or c.plank_skin != null:
				print("ART P23: %s should use a plain Sprite2D" % kind)
				bad += 1
			elif not (c.sprite.scale * c.sprite.texture.get_size()).is_equal_approx(want):
				print("ART P23: %s sprite drawn at %s, not %s" % [kind, c.sprite.scale * c.sprite.texture.get_size(), want])
				bad += 1
		c.free()
	for kind in CARGO_SIZES:
		var tpath: String = ArtAssets.CARGO_THUMB_DIR + kind + ".png"
		var th := ArtAssets.cargo_thumb(kind)
		bad += _slot(tpath, th, SQ_THUMB, present, missing)
		var want_thumb: Texture2D = th if th else Cargo.texture_for(kind)
		if Cargo.thumb_for(kind) != want_thumb:
			print("ART P23: Cargo.thumb_for(%s) wrong source" % kind)
			bad += 1

	# ---- (b) stars: big (results, header) and small (HUD bar, tiles)
	var on := ArtAssets.star_texture(true)
	var off := ArtAssets.star_texture(false)
	bad += _slot(ArtAssets.STAR_ON, on, SQ_STAR, present, missing)
	bad += _slot(ArtAssets.STAR_OFF, off, SQ_STAR, present, missing)
	var on_s: Texture2D = ArtAssets.try_texture(ArtAssets.STAR_ON_S)
	var off_s: Texture2D = ArtAssets.try_texture(ArtAssets.STAR_OFF_S)
	bad += _slot(ArtAssets.STAR_ON_S, on_s, SQ_STAR_S, present, missing)
	bad += _slot(ArtAssets.STAR_OFF_S, off_s, SQ_STAR_S, present, missing)
	if ArtAssets.star_texture(true, true) != (on_s if on_s else on):
		print("ART P23: small on-star does not fall back to the big one")
		bad += 1
	if ArtAssets.star_texture(false, true) != (off_s if off_s else off):
		print("ART P23: small off-star does not fall back to the big one")
		bad += 1
	if Screens.star_on() != (on if on else Screens.STAR_TEX):
		print("ART P23: Screens.star_on() wrong source")
		bad += 1
	var hs: Dictionary = Hud.hud_stars()
	var hud_on: Texture2D = on_s if on_s else on
	if hud_on:
		if hs.on != hud_on or hs.size != ArtAssets.HUD_STAR_SIZE_V3 or hs.off != (off_s if off_s else off):
			print("ART P23: HUD does not use the v3 star at %d px" % ArtAssets.HUD_STAR_SIZE_V3)
			bad += 1
		if ArtAssets.HUD_STAR_SIZE_V3 < ArtAssets.HUD_STAR_SIZE:
			print("ART P23: v3 HUD star is smaller than v2")
			bad += 1
	elif hs.on != Hud.STAR_TEX or hs.size != 26.0 or hs.off != null:
		print("ART P23: HUD stars are not the v2 look (v2 star, 26 px, tinted empty)")
		bad += 1

	# ---- (c) icons: padlock, arrows (+ the Phase 1 pause / sound files if dropped)
	var lock := ArtAssets.padlock_icon()
	bad += _slot(ArtAssets.ICON_PADLOCK, lock, SQ_LOCK, present, missing)
	if Screens.lock_tex() != (lock if lock else Screens.LOCK_TEX):
		print("ART P23: Screens.lock_tex() wrong source")
		bad += 1
	var right := ArtAssets.arrow_icon(false)
	var left := ArtAssets.arrow_icon(true)
	bad += _slot(ArtAssets.ICON_ARROW_RIGHT, right, SQ_ARROW, present, missing)
	bad += _slot(ArtAssets.ICON_ARROW_LEFT, left, SQ_ARROW, present, missing)
	var r_used := Screens.arrow_tex(false)
	if right and r_used != right:
		print("ART P23: right arrow ignores v3")
		bad += 1
	if right == null and r_used.resource_path != Screens.RIGHT_ICON_V2:
		print("ART P23: right arrow fallback is not v2 right.png")
		bad += 1
	var l_used := Screens.arrow_tex(true)
	if left and l_used != left:
		print("ART P23: left arrow ignores v3 arrow_left.png")
		bad += 1
	if left == null:
		# mirrored right arrow, pixel-identical to flipping the source by hand
		var want_img: Image = (right if right else load(Screens.RIGHT_ICON_V2)).get_image().duplicate()
		want_img.flip_x()
		var got_img: Image = l_used.get_image()
		if got_img.get_size() != want_img.get_size() or got_img.get_data() != want_img.get_data():
			print("ART P23: left arrow fallback is not the mirrored right arrow")
			bad += 1
	for v2 in ArtAssets.V2_ICON_TO_V3:
		var v3p: String = ArtAssets.V2_ICON_TO_V3[v2]
		var t3: Texture2D = ArtAssets.try_texture(v3p)
		bad += _slot(v3p, t3, SQ_HUD_ICON, present, missing)
		var used: Texture2D = ArtAssets.hud_icon(v2)
		if (t3 and used != t3) or (t3 == null and used.resource_path != v2):
			print("ART P23: HUD icon %s wrong source" % v2.get_file())
			bad += 1

	# ---- (d) V8 world icons
	var shared: Texture2D = ArtAssets.try_texture(ArtAssets.WORLD_ICON_SHARED)
	bad += _slot(ArtAssets.WORLD_ICON_SHARED, shared, WORLD_ICON, present, missing)
	for wi in Levels.WORLDS.size():
		var w: Dictionary = Levels.WORLDS[wi]
		var wpath: String = ArtAssets.WORLD_ICON_DIR + ArtAssets.world_key(w.name) + ".png"
		var own: Texture2D = ArtAssets.try_texture(wpath)
		bad += _slot(wpath, own, WORLD_ICON, present, missing)
		var icon := WorldIcons.make(w.get("icon", ""), wi)
		var want_tex: Texture2D = own if own else shared
		if icon.tex != want_tex:
			print("ART P23: world icon for world %d (%s) wrong source" % [wi, w.name])
			bad += 1
		var want_box: Vector2 = ArtAssets.WORLD_ICON_SIZE_V3 if want_tex else Vector2(96, 56)
		if icon.custom_minimum_size != want_box:
			print("ART P23: world icon box %s != %s" % [icon.custom_minimum_size, want_box])
			bad += 1
		if want_tex and ((want_box * 0.625).x < 48 or (want_box * 0.625).y < 30):
			print("ART P23: v3 world icon under 48x30 at 800x450")
			bad += 1
		icon.free()

	# ---- (e) skies: S2 Woods, S3 Desert, S6 Freight Yard, S7 Downtown
	for wname in ArtAssets.PHASE3_BG_WORLDS:
		var path: String = ArtAssets.world_background_path(wname)
		var tex := ArtAssets.world_background(wname)
		bad += _slot(path, tex, SKY, present, missing)
		var w := _world(wname)
		if w.is_empty():
			print("ART P23: world %s not found" % wname)
			bad += 1
		elif w.has("backdrop") == w.has("bg"):
			print("ART P23: %s data changed (bg / backdrop)" % wname)
			bad += 1
		elif w.has("bg") and not String(w.bg).begins_with("res://art/v2/bg/"):
			print("ART P23: %s v2 bg path changed" % wname)
			bad += 1
	if ArtAssets.world_background_path("TOWN") != ArtAssets.TOWN_BG:
		print("ART P23: Town sky path moved")
		bad += 1

	if expect == "empty" and not present.is_empty():
		print("ART P23: --p23=empty but present: %s" % [present])
		bad += present.size()
	if expect == "present" and not missing.is_empty():
		print("ART P23: --p23=present but missing: %s" % [missing])
		bad += missing.size()
	print("ART P23: %d slot(s) present, %d missing (old look)" % [present.size(), missing.size()])
	return bad


func _world(wname: String) -> Dictionary:
	for w in Levels.WORLDS:
		if w.name == wname:
			return w
	return {}

