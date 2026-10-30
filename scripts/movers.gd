class_name Movers
extends RefCounted
## Moving obstacle factory: level data "movers": [{"type": "<id>", ...}].

const SCRIPTS = {
	"crane": "res://scripts/movers/crane.gd",  # M16
	"garage_door": "res://scripts/movers/garage_door.gd",  # M17
	"bus": "res://scripts/movers/bus.gd",  # M18 (also "kind": "train")
	"forklift": "res://scripts/movers/forklift.gd",  # M22
	"ski_lift": "res://scripts/movers/ski_lift.gd",  # M19
	"swinging_log": "res://scripts/movers/swinging_log.gd",  # M20
	"windmill": "res://scripts/movers/windmill.gd",  # M21
	"tumbleweed": "res://scripts/movers/tumbleweed.gd",  # Desert pusher (M22 reskin)
	"conveyor": "res://scripts/movers/conveyor.gd",  # M23
	"tree": "res://scripts/movers/tree.gd",  # Woods: crown swaying in the wind
	"tower_crane": "res://scripts/movers/tower_crane.gd",  # M16 variant (Construction)
}


static func make(id: String) -> Mover:
	assert(SCRIPTS.has(id), "unknown mover type %s" % id)
	return load(SCRIPTS[id]).new()
