extends SceneTree
## Merge one bot --json result file into another (used by tools/parity.sh record).
##   godot --headless -s res://tools/merge_results.gd -- --into=res://a.json --from=/tmp/b.json
func _init():
	var into := ""
	var from := ""
	for a in OS.get_cmdline_user_args():
		var p = a.trim_prefix("--").split("=")
		if p[0] == "into": into = p[1]
		if p[0] == "from": from = p[1]
	var add = JSON.parse_string(FileAccess.get_file_as_string(from))
	var base = {"error": add.error, "seed": add.seed, "levels": []}
	if FileAccess.file_exists(into):
		base = JSON.parse_string(FileAccess.get_file_as_string(into))
	var mine = {}
	for r in add.levels:
		mine[int(r.level)] = true
	var levels = []
	for r in base.levels:
		if not mine.has(int(r.level)):
			levels.append(r)
	levels.append_array(add.levels)
	levels.sort_custom(func(a, b): return a.level < b.level)
	base.levels = levels
	var f = FileAccess.open(into, FileAccess.WRITE)
	f.store_string(JSON.stringify(base, "  ") + "\n")
	f.close()
	quit()
