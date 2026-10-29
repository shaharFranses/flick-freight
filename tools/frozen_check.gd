extends SceneTree
## Frozen-data gate: levels 1-40 must never change (docs/EXPANSION_PLAN_2.md §1).
## Hashes their dictionaries from levels.gd and compares with tools/frozen_levels.sha256.
##   godot --headless -s res://tools/frozen_check.gd            (check, exit 1 on change)
##   godot --headless -s res://tools/frozen_check.gd -- --write (record a new hash)

const FROZEN := 40
const HASH_FILE := "res://tools/frozen_levels.sha256"


func _init():
	var text = var_to_str(Levels.DATA.slice(0, FROZEN))
	var h = text.sha256_text()
	if "--write" in OS.get_cmdline_user_args():
		var f = FileAccess.open(HASH_FILE, FileAccess.WRITE)
		f.store_string(h + "\n")
		f.close()
		print("FROZEN DATA: wrote %s" % h)
		quit(0)
		return
	var want = FileAccess.get_file_as_string(HASH_FILE).strip_edges()
	if h == want:
		print("FROZEN DATA: OK (levels 1-%d unchanged)" % FROZEN)
		quit(0)
	else:
		print("FROZEN DATA: FAIL, levels 1-%d changed (%s != %s)" % [FROZEN, h, want])
		quit(1)
