class_name CargoVehicle
extends Node2D
## Anything cargo gets loaded into (docs/EXPANSION_PLAN_2.md §3.3). The level, the HUD
## and the QA bot only talk to vehicles through this interface. The original truck (V0)
## implements it unchanged; every new vehicle is its own script extending this.
##
## Convention: the origin is the middle of the load floor's top surface; the rear (open)
## end faces the dock on the left.

signal arrived
signal departed

var state := "away"  # away / arriving / parked / leaving
var loads: Array = []  # [{"cargo": Cargo, "offset", "rot", "local", "lrot", "counted"}]
var height_limit := 0.0  # M14: low bridge clearance above the load floor (0 = none)
var lift_off_on_win := false  # helicopter, balloon: leave() as the showcase when the level is won


func setup(_cfg: Dictionary, _palette_index: int, _wall_height: float):
	pass


## Where the vehicle sits on the road (y of the load floor), given the road surface.
func floor_y(road_y: float) -> float:
	return road_y


func arrive():
	pass


func leave():
	pass


func is_parked() -> bool:
	return state == "parked"


## Is this point inside the load zone (counts as delivered when cargo settles here)?
func contains_point(_p: Vector2) -> bool:
	return false


## Is this point anywhere on the vehicle (used to measure settling relative to it)?
func on_vehicle(_p: Vector2) -> bool:
	return false


func point_velocity(_p: Vector2) -> Vector2:
	return Vector2.ZERO


func add_load(_c: Cargo, _counted := true):
	pass


func remove_load(_c: Cargo) -> bool:
	return false


func load_count() -> int:
	return loads.size()


## Strap every loose load down where it is now (end of level / driving off).
func glue_all():
	pass


func top_center() -> Vector2:
	return global_position


# ---------------------------------------------------------------- for the QA bot
## Pose `dt` seconds from now: [position, rotation].
func predict_pose(_dt: float) -> Array:
	return [global_position, rotation]


## Frames for one cycle of a vehicle that moves on the level clock (0 = it doesn't).
func period_frames() -> int:
	return 0


## Horizontal speed `dt` seconds from now.
func predict_vx(_dt: float) -> float:
	return 0.0


## Shape the bot scores landings against, in local space:
## {floor_w, rear_t, rear_h, front_x0, front_w, front_h, slippery}
## The load floor spans [-floor_w/2, floor_w/2]; the rear wall sits just left of it and the
## front block (bulkhead + cab) spans [front_x0, front_x0 + front_w].
func sim_profile() -> Dictionary:
	return {}
