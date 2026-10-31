extends SceneTree
## Save compatibility (docs/EXPANSION_PLAN_2.md §1.3): saves are keyed by level ID (index in
## Levels.DATA). For old saves, levels 1-40 inside a world unlock as under the old rule
## ("level 0, or the level before has a star"), a won level never locks, and a world opens
## once every level of the world before it is won (or the player already won one of its levels).
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
			# inside a world, levels 1-40 still chain like the old rule; a level you've won is
			# always open. (World starts follow the world rule, checked below.)
			var w_first = Levels.levels_in_world_ordered(Levels.DATA[i].world)[0] == i
			if (w_first and i > 0) or i in Levels.RETIRED:
				continue
			var prev = i - 1
			while prev in Levels.RETIRED:
				prev -= 1  # retired levels drop out of the chain
			var old_rule = i == 0 or SaveData.stars(prev) > 0 or SaveData.stars(i) > 0
			if SaveData.unlocked(i) != old_rule:
				fails += 1
				print("SAVE: level %d unlocked=%s, old rule says %s (save %s)" % [i + 1, SaveData.unlocked(i), old_rule, s])
		# stars are read back by ID
		for i in s:
			if SaveData.stars(i) != s[i]:
				fails += 1
	# world rule: the next world opens only when every level of the one before is won
	for wk in range(1, Levels.WORLD_ORDER.size()):
		var prev: Array = Levels.levels_in_world_ordered(Levels.WORLD_ORDER[wk - 1])
		var first: int = Levels.levels_in_world_ordered(Levels.WORLD_ORDER[wk])[0]
		SaveData._cfg = ConfigFile.new()
		for j in prev.slice(0, prev.size() - 1):
			SaveData._cfg.set_value("stars", str(j), 1)
		cases += 2
		if SaveData.unlocked(first):
			fails += 1
			print("SAVE: world %d opened with one level of the world before still unwon" % wk)
		SaveData._cfg.set_value("stars", str(prev[-1]), 1)
		if not SaveData.unlocked(first):
			fails += 1
			print("SAVE: world %d still locked after every level of the world before was won" % wk)
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
