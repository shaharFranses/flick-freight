class_name Movers
extends RefCounted
## Moving obstacle factory: level data "movers": [{"type": "<id>", ...}].

const SCRIPTS = {}


static func make(id: String) -> Mover:
	assert(SCRIPTS.has(id), "unknown mover type %s" % id)
	return load(SCRIPTS[id]).new()
