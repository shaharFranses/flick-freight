extends VehicleBase
## V5: dump truck with its bed tilted back toward the dock. Cargo slides back against a low
## tailgate, so order matters: heavy crates make good stoppers.
## cfg: tilt (deg, bed angle; default 10)
##      piston {amp (deg), period (s)}: the hydraulic ram tips the bed from `tilt` up to
##      tilt + amp and back down on the vehicle's own clock (identical on every restart)

const BED := 240.0
const GATE := 34.0
var tilt := 10.0
var tilt0 := 10.0  # bed angle with the ram all the way down
var piston_amp := 0.0
var piston_period := 5.0
var cab_body: AnimatableBody2D


func _define(cfg: Dictionary) -> Dictionary:
	tilt = cfg.get("tilt", 10.0)
	tilt0 = tilt
	var pc: Dictionary = cfg.get("piston", {})
	piston_amp = pc.get("amp", 0.0)
	piston_period = max(1.0, pc.get("period", 5.0))
	rotation = -deg_to_rad(tilt)  # rear (left) end lower (the base reads "tilt" too)
	var half = BED * 0.5
	return {
		"zone": Rect2(-half + 2, -300, BED - 4, 300),
		"floor_w": BED,
		"floor": Rect2(-half - 8, 0, BED + 16, 16),
		"rear": Rect2(-half - 8, -GATE, 8, GATE),
		"walls": [Rect2(half, -110, 12, 110)],  # headboard
		"front": [],
		"reach": Rect2(-half - 60, -320, BED + 140, 360),
		"ride": 92.0,
		"wheels": [],
	}


## The cab and wheels stay level on the road; only the bed is tipped. They're drawn here,
## counter-rotated, and the cab is a separate body that isn't tilted.
func _build_bodies():
	super._build_bodies()
	var cab = AnimatableBody2D.new()
	cab.sync_to_physics = false
	cab.add_to_group("truck_cab")
	var cs = CollisionShape2D.new()
	var cp = ConvexPolygonShape2D.new()
	cp.points = _cab_poly()
	cs.shape = cp
	cab.add_child(cs)
	cab.rotation = deg_to_rad(tilt)  # undo the vehicle's tilt
	add_child(cab)
	cab_body = cab


## Bed angle (deg) t seconds after parking: down at `tilt0`, up to tilt0 + piston_amp.
func _tilt_at(t: float) -> float:
	if piston_amp <= 0.0:
		return tilt0
	return tilt0 + piston_amp * (0.5 - 0.5 * cos(TAU * t / piston_period))


func _physics_process(delta: float):
	super._physics_process(delta)
	if piston_amp > 0.0 and state == "parked":
		tilt = _tilt_at(_t)
		rotation = -deg_to_rad(tilt)
		cab_body.rotation = deg_to_rad(tilt)  # the cab stays level
		front_layer.queue_redraw()


func predict_pose(dt: float) -> Array:
	var pose = super.predict_pose(dt)
	if piston_amp > 0.0:
		pose[1] = -deg_to_rad(_tilt_at(_t + dt))
	return pose


func _cab_poly() -> PackedVector2Array:
	var x0 = BED * 0.5 + 16
	var y0 = 0.0
	return PackedVector2Array([Vector2(x0, y0 + 30), Vector2(x0, y0 - 100), Vector2(x0 + 70, y0 - 100),
		Vector2(x0 + 100, y0 - 50), Vector2(x0 + 128, y0 - 44), Vector2(x0 + 128, y0 + 30)])


func _draw_back(n: Node2D):
	var half = BED * 0.5
	# far side of the tipped bed, behind the cargo
	ArtDraw.bed_wall(n, Rect2(-half, -60, BED, 60), 3, true)


func _draw_front(n: Node2D):
	var half = BED * 0.5
	var col: Array = ArtPalette.VEHICLE.dump
	# tipped bed: floor, low tailgate, headboard (the near side is left off: open cutaway)
	ArtDraw.panel(n, Rect2(-half - 8, 0, BED + 20, 16), col, ArtDraw.PROP, 4.0, 4.0)
	ArtDraw.ink_rect(n, Rect2(-half - 8, -GATE, 8, GATE + 6), col[0], 2.5)
	ArtDraw.panel(n, Rect2(half, -110, 12, 122), col, 3.0, 5.0, 0.0)
	# chassis, cab and wheels drawn level: counter-rotate around the origin
	n.draw_set_transform(Vector2.ZERO, deg_to_rad(tilt), Vector2.ONE)
	ArtDraw.ink_rect(n, Rect2(-half - 10, 34, BED + 150, 18), ArtPalette.STEEL, ArtDraw.PROP)
	# hydraulic ram: from the chassis up to the underside of the bed, wherever that is now
	var ram_top = Vector2(half - 70, 16).rotated(-deg_to_rad(tilt))
	ArtDraw.ink_line(n, Vector2(half - 110, 40), ram_top, ArtPalette.CHROME, 11.0, 3.0)
	ArtDraw.cab(n, _cab_poly(), col)
	for w in [Vector2(-half + 50, 62), Vector2(half - 30, 62), Vector2(half + 100, 62)]:
		ArtDraw.wheel(n, w, 30.0)
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
