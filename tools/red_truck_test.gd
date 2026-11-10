extends SceneTree
## Assert the V0 truck always resolves to the red palette (#E4572E / #B83F1F),
## for every level and every palette index that used to cycle colours.
## Special vehicles keep their type so bed physics stay unchanged.
##   godot --headless -s res://tools/red_truck_test.gd

func _init():
	var red := Color("#E4572E")
	var dark := Color("#B83F1F")
	var bad := 0
	for requested in [0, 1, 2, 3, 4, 17, 99]:
		if Truck.resolved_palette_index(requested) != Truck.RED_PALETTE_INDEX:
			print("RED TRUCK: index %d did not resolve to %d" % [requested, Truck.RED_PALETTE_INDEX])
			bad += 1
		var pal: Array = Truck.resolved_palette(requested)
		if pal.size() < 2 or not pal[0].is_equal_approx(red) or not pal[1].is_equal_approx(dark):
			print("RED TRUCK: index %d resolved to %s, not red" % [requested, pal])
			bad += 1
	var truck_levels := 0
	var worlds_with_truck := {}
	for i in Levels.count():
		var lv: Dictionary = Levels.get_level(i)
		var trucks: Array = lv.trucks if lv.has("trucks") else [lv.truck]
		for t in trucks:
			var id: String = t.get("vehicle", "truck")
			if id != "truck":
				continue
			truck_levels += 1
			worlds_with_truck[lv.world] = true
			# Previously game.gd used level_index + truck_count, which cycled colours.
			if Truck.resolved_palette_index(i) != Truck.RED_PALETTE_INDEX:
				print("RED TRUCK L%d (world %d): palette did not resolve to red" % [i, lv.world])
				bad += 1
			var pal: Array = Truck.resolved_palette(i)
			if not pal[0].is_equal_approx(red) or not pal[1].is_equal_approx(dark):
				print("RED TRUCK L%d: body colour is %s / %s" % [i, pal[0], pal[1]])
				bad += 1
	if truck_levels == 0:
		print("RED TRUCK: no V0 truck levels found")
		bad += 1
	# Every world that uses the V0 truck must resolve to red (already checked
	# per level). Require at least the early worlds (Town / Woods / Harbor / …)
	# so a typo that skips DATA cannot silently pass.
	if worlds_with_truck.size() < 3:
		print("RED TRUCK: only %d worlds use the V0 truck" % worlds_with_truck.size())
		bad += 1
	print("RED TRUCK CHECK: %d problem(s) across %d V0-truck configs in %d worlds" % [bad, truck_levels, worlds_with_truck.size()])
	quit(1 if bad else 0)
