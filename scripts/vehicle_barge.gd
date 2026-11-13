extends VehicleBase
## V11: harbor barge. A long open deck riding on the water: no walls, only a low lip at each
## end, and it rocks on the waves. Cargo has to land soft and flat.
## cfg: rock {amp_y (px), amp_rot (deg), period (s)}

const DECK := 360.0
const LIP := 12.0
var rock := {}
var _base_y := 0.0
var _has_base := false


func _define(cfg: Dictionary) -> Dictionary:
	rock = cfg.get("rock", {})
	var half = DECK * 0.5
	return {
		"zone": Rect2(-half + 2, -300, DECK - 4, 300),
		"floor_w": DECK,
		"floor": Rect2(-half - 8, 0, DECK + 16, 16),
		"rear": Rect2(-half - 8, -LIP, 8, LIP),
		"walls": [Rect2(half, -LIP, 8, LIP)],
		# wheelhouse at the bow: landing on it is a miss
		"front": [PackedVector2Array([Vector2(half + 10, 16), Vector2(half + 10, -74), Vector2(half + 66, -74),
			Vector2(half + 80, -30), Vector2(half + 80, 16)])],
		"reach": Rect2(-half - 60, -320, DECK + 200, 380),
		"ride": 34.0,
		"wheels": [],
	}


func _phase(t: float) -> float:
	return TAU * t / max(0.5, rock.get("period", 3.2))


func _physics_process(delta: float):
	if not _has_base:
		_base_y = position.y
		_has_base = true
	super._physics_process(delta)
	if not rock.is_empty() and state != "away":
		var ph = _phase(_t)
		position.y = _base_y + rock.get("amp_y", 12.0) * sin(ph)
		rotation = deg_to_rad(rock.get("amp_rot", 4.0)) * sin(ph + 0.9)


func predict_pose(dt: float) -> Array:
	var pose = super.predict_pose(dt)
	if not rock.is_empty() and _has_base:
		var ph = _phase(_t + dt)
		pose[0].y = _base_y + rock.get("amp_y", 12.0) * sin(ph)
		pose[1] = deg_to_rad(rock.get("amp_rot", 4.0)) * sin(ph + 0.9)
	return pose


func _draw_back(n: Node2D):
	var half = DECK * 0.5
	# hull, behind the cargo: wide at the deck, narrower at the waterline
	var hull = PackedVector2Array([Vector2(-half - 16, 4), Vector2(half + 96, 4), Vector2(half + 70, 62), Vector2(-half + 10, 62)])
	ArtDraw.ink_poly(n, hull, ArtPalette.CORAL, ArtDraw.PROP)
	n.draw_colored_polygon(PackedVector2Array([Vector2(-half - 2, 34), Vector2(half + 80, 34), Vector2(half + 70, 58), Vector2(-half + 12, 58)]), ArtPalette.CORAL_SHADE)


func _draw_front(n: Node2D):
	var half = DECK * 0.5
	# deck plate with a low lip at each end, and the wheelhouse
	ArtDraw.ink_rect(n, Rect2(-half - 8, 0, DECK + 16, 16), ArtPalette.STEEL, ArtDraw.PROP)
	n.draw_rect(Rect2(-half - 4, 4, DECK + 8, 5), ArtPalette.DECK_PLATE)
	ArtDraw.ink_rect(n, Rect2(-half - 8, -LIP, 8, LIP + 4), ArtPalette.STEEL_LIGHT, 2.5)
	ArtDraw.ink_rect(n, Rect2(half, -LIP, 8, LIP + 4), ArtPalette.STEEL_LIGHT, 2.5)
	ArtDraw.ink_poly(n, shape.front[0], ArtPalette.CREAM, ArtDraw.PROP)
	ArtDraw.ink_rect(n, Rect2(half + 20, -62, 34, 22), ArtPalette.BLUE, 2.5)
