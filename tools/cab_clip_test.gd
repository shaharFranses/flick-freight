extends SceneTree
## Assert the parked V0 truck cab and front bumper stay inside the 1280-wide view
## on every level. The runtime clamp lives in Truck.fitted_base_x / Truck.setup;
## levels 1-40 are not edited (frozen_check stays green).
##   godot --headless -s res://tools/cab_clip_test.gd

func _init():
	var bad := 0
	var clamped := 0
	var checked := 0
	var front_ext: float = Truck.visual_front_extent()
	var max_x: float = Truck.VIEW_WIDTH - Truck.CAB_VIEW_MARGIN - front_ext
	# cab_points() right edge, relative to the bed centre
	var cab_right: float = Truck.BED_W * 0.5 + Truck.WALL_T + 4 + Truck.CAB_W  # 303
	for i in Levels.count():
		var lv: Dictionary = Levels.get_level(i)
		var trucks: Array = lv.trucks if lv.has("trucks") else [lv.truck]
		for t in trucks:
			if t.get("vehicle", "truck") != "truck":
				continue
			checked += 1
			var authored: float = t.x
			var fitted: float = Truck.fitted_base_x(authored)
			# setup must apply the same clamp
			var truck := Truck.new()
			truck.setup(t, 0, t.get("wall", 52))
			if not is_equal_approx(truck.base_x, fitted):
				print("CAB CLIP L%d: setup base_x %.1f != fitted_base_x %.1f" % [
					Levels.number_of(i), truck.base_x, fitted])
				bad += 1
			if fitted > max_x + 0.01:
				print("CAB CLIP L%d (id %d): fitted x %.1f is past max %.1f" % [
					Levels.number_of(i), i, fitted, max_x])
				bad += 1
			var front: float = fitted + front_ext
			if front > Truck.VIEW_WIDTH + 0.01:
				print("CAB CLIP L%d (id %d): bumper at %.1f is past the view (%.0f)" % [
					Levels.number_of(i), i, front, Truck.VIEW_WIDTH])
				bad += 1
			if fitted + cab_right > Truck.VIEW_WIDTH + 0.01:
				print("CAB CLIP L%d (id %d): cab body at %.1f is past the view" % [
					Levels.number_of(i), i, fitted + cab_right])
				bad += 1
			if not is_equal_approx(authored, fitted):
				clamped += 1
				var n = Levels.number_of(i)
				var label = "L%d" % n if n > 0 else "id%d" % i
				print("  clamp %s %s: authored x=%.0f -> %.0f (dx %+.0f, bumper at %.0f)" % [
					label, Levels.world_of(i).name, authored, fitted, fitted - authored,
					fitted + front_ext])
			truck.free()
	if checked == 0:
		print("CAB CLIP: no V0 truck levels found")
		bad += 1
	# Harbor L31 (play-order number 31, data id 15) is the reported clip; it must move.
	var l31: Dictionary = Levels.get_level(Levels.id_of_number(31))
	if l31.get("world", -1) != 3:
		print("CAB CLIP: play-order 31 is not Harbor")
		bad += 1
	else:
		var authored31: float = l31.truck.x
		var fitted31: float = Truck.fitted_base_x(authored31)
		if authored31 + front_ext <= Truck.VIEW_WIDTH:
			print("CAB CLIP: Harbor L31 authored bumper (%.1f) already on-screen; test stale?" % [
				authored31 + front_ext])
			bad += 1
		if fitted31 + front_ext > Truck.VIEW_WIDTH - Truck.CAB_VIEW_MARGIN + 0.01:
			print("CAB CLIP: Harbor L31 still clips after the clamp")
			bad += 1
	print("CAB CLIP CHECK: %d problem(s); clamped %d of %d V0-truck configs (max parked x=%.0f)" % [
		bad, clamped, checked, max_x])
	quit(1 if bad else 0)
