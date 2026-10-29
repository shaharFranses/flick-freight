class_name Movers
extends RefCounted
## Moving obstacle factory: level data "movers": [{"type": "<id>", ...}].

const SCRIPTS = {
	"crane": "res://scripts/movers/crane.gd",  # M16
	"garage_door": "res://scripts/movers/garage_door.gd",  # M17
	"bus": "res://scripts/movers/bus.gd",  # M18 (also "kind": "train")
	"forklift": "res://scripts/movers/forklift.gd",  # M22
}


static func make(id: String) -> Mover:
	assert(SCRIPTS.has(id), "unknown mover type %s" % id)
	return load(SCRIPTS[id]).new()
