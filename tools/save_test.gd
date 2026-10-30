extends SceneTree
## Save compatibility (docs/EXPANSION_PLAN_2.md §1.3): saves are keyed by level ID (index in
## Levels.DATA). For old saves, levels 1-40 must unlock exactly as under the old rule
## ("level 0, or the level before has a star").
##   godot --headless -s res://tools/save_test.gd

const OLD := 40


func _init():
	var fails = 0
	var cases = 0
	# saves with the first k levels beaten, plus a few with gaps
	var saves: Array = []
	for k in OLD + 1:
		var s = {}
		for i in k:
			s[i] = 1 + i % 3
		saves.append(s)
	saves.append({0: 3, 1: 2, 5: 1, 6: 2})
	saves.append({3: 1, 10: 2, 11: 3, 39: 1})
	for s in saves:
		SaveData._cfg = ConfigFile.new()
		for i in s:
			SaveData._cfg.set_value("stars", str(i), s[i])
		for i in OLD:
			cases += 1
			var old_rule = i == 0 or SaveData.stars(i - 1) > 0
			if SaveData.unlocked(i) != old_rule:
				fails += 1
				print("SAVE: level %d unlocked=%s, old rule says %s (save %s)" % [i + 1, SaveData.unlocked(i), old_rule, s])
		# stars are read back by ID
		for i in s:
			if SaveData.stars(i) != s[i]:
				fails += 1
	# IDs 1-40 still play in their original order
	var order = Levels.order()
	var kept = range(OLD).filter(func(i): return not i in Levels.RETIRED)
	for k in kept.size() - 1:
		var i = kept[k]
		if order.find(i) > order.find(kept[k + 1]):
			fails += 1
			print("SAVE: level %d is played after level %d" % [i + 1, kept[k + 1] + 1])
	print("SAVE TEST: %d case(s), %d failure(s)" % [cases, fails])
	quit(1 if fails else 0)
