class_name SaveData
extends RefCounted
## Tiny persistent store (user:// maps to IndexedDB on the web build).

const PATH = "user://flick_freight_v2.cfg"
static var _cfg: ConfigFile = null


static func _c() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(PATH)  # missing file is fine on first run
	return _cfg


static func _save():
	_c().save(PATH)


static func stars(level: int) -> int:
	return int(_c().get_value("stars", str(level), 0))


static func set_stars(level: int, value: int):
	if value > stars(level):
		_c().set_value("stars", str(level), value)
		_save()


static func total_stars() -> int:
	var t = 0
	for i in Levels.count():
		t += stars(i)
	return t


static func unlocked(level: int) -> bool:
	return level == 0 or stars(level - 1) > 0


static func first_unbeaten() -> int:
	for i in Levels.count():
		if stars(i) == 0:
			return i
	return Levels.count() - 1


static func get_flag(key: String, default_val = false):
	return _c().get_value("flags", key, default_val)


static func set_flag(key: String, value):
	_c().set_value("flags", key, value)
	_save()


static func reset_all():
	_cfg = ConfigFile.new()
	_save()
