class_name Vehicles
extends RefCounted
## Vehicle factory: a level's truck config picks its vehicle with "vehicle": "<id>".
## Missing = the original truck (V0), so levels 1-40 are unchanged.

const SCRIPTS = {
	"truck": "res://scripts/truck.gd",
}


static func make(id: String) -> CargoVehicle:
	return load(SCRIPTS.get(id, SCRIPTS.truck)).new()
