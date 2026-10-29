class_name Vehicles
extends RefCounted
## Vehicle factory: a level's truck config picks its vehicle with "vehicle": "<id>".
## Missing = the original truck (V0), so levels 1-40 are unchanged.

const SCRIPTS = {
	"truck": "res://scripts/truck.gd",
	"moto": "res://scripts/vehicle_moto.gd",  # V1
	"garbage": "res://scripts/vehicle_garbage.gd",  # V3
	"pickup": "res://scripts/vehicle_pickup.gd",  # V2
	"dump": "res://scripts/vehicle_dump.gd",  # V5
	"flatbed": "res://scripts/vehicle_flatbed.gd",  # V6
	"flatcar": "res://scripts/vehicle_flatcar.gd",  # V7
	"heli": "res://scripts/vehicle_heli.gd",  # V8
	"balloon": "res://scripts/vehicle_balloon.gd",  # V9
}


static func make(id: String) -> CargoVehicle:
	return load(SCRIPTS.get(id, SCRIPTS.truck)).new()
