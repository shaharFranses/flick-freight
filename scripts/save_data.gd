class_name SaveData
extends RefCounted
## Tiny persistent store (user:// maps to IndexedDB on the web build).

const PATH = "user://flick_freight_v2.cfg"
static var _cfg: ConfigFile = null
## Dev (?fresh=1 / --fresh=1): play as a brand-new player. The save starts empty, lives only in
## memory and is never written, so the real save is untouched.
static var fresh := false


static func _c() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		if not fresh:
			_cfg.load(PATH)
			_merge_account_save()  # missing file is fine on first run
	return _cfg


static func _save():
	if fresh:
		return
	_c().save(PATH)
	Portal.save_set(_c().encode_to_text())  # CrazyGames account (no-op elsewhere)


## CrazyGames: fold the account's save into the browser's, keeping the better result per level,
## so progress follows the player to another device and nothing local is lost.
static func _merge_account_save():
	var text := Portal.save_get()
	if text == "":
		return
	var remote := ConfigFile.new()
	if remote.parse(text) != OK:
		return
	var changed := false
	for section in remote.get_sections():
		for key in remote.get_section_keys(section):
			var rv = remote.get_value(section, key)
			var lv = _cfg.get_value(section, key, null)
			var better = lv == null
			if not better and (rv is int or rv is float) and (lv is int or lv is float):
				better = rv > lv
			elif not better and rv is bool and lv is bool:
				better = rv and not lv
			if better:
				_cfg.set_value(section, key, rv)
				changed = true
	if changed:
		_cfg.save(PATH)


static func stars(level: int) -> int:
	return int(_c().get_value("stars", str(level), 0))


static func set_stars(level: int, value: int):
	if value > stars(level):
		_c().set_value("stars", str(level), value)
		_save()


static func total_stars() -> int:
	var t = 0
	for i in Levels.order():
		t += stars(i)
	return t


static func unlocked(level: int) -> bool:
	return Levels.unlocked(level)


## First level (in play order) that's open but not beaten yet.
static func first_unbeaten() -> int:
	for i in Levels.order():
		if stars(i) == 0 and Levels.unlocked(i):
			return i
	return Levels.order()[-1]


static func get_flag(key: String, default_val = false):
	return _c().get_value("flags", key, default_val)


static func set_flag(key: String, value):
	_c().set_value("flags", key, value)
	_save()


static func reset_all():
	_cfg = ConfigFile.new()
	_save()
