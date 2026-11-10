extends SceneTree
## Assert V0 truck cabs stay inside the 1280-wide view: parked bed centres are
## clamped, and moving paths are remapped so the right extreme is at most
## max_bed_x() (959) while the left extreme and period stay the same.
## Runtime only (Truck.fitted_base_x / fitted_drive / setup); levels 1-40 are
## not edited (frozen_check stays green). Special vehicles are skipped.
##   godot --headless -s res://tools/cab_clip_test.gd

func _init():
	var bad := 0
	var clamped := 0
	var remapped := 0
	var checked := 0
	var front_ext: float = Truck.visual_front_extent()
	var max_x: float = Truck.max_bed_x()
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
			var authored_amp := float(t.get("amp", 0.0))
			var authored_period := maxf(0.5, float(t.get("period", 4.0)))
			var fitted: float = Truck.fitted_base_x(authored)
			var drive: Vector2 = Truck.fitted_drive(authored, authored_amp)
			var old_left := fitted - authored_amp
			var old_right := fitted + authored_amp
			# setup must apply the same parked clamp and path remap
			var truck := Truck.new()
			truck.setup(t, 0, t.get("wall", 52))
			if not is_equal_approx(truck.base_x, drive.x) or not is_equal_approx(truck.amp, drive.y):
				print("CAB CLIP L%d: setup (%.1f, amp %.1f) != fitted_drive (%.1f, amp %.1f)" % [
					Levels.number_of(i), truck.base_x, truck.amp, drive.x, drive.y])
				bad += 1
			if not is_equal_approx(truck.period, authored_period):
				print("CAB CLIP L%d: period %.3f != authored %.3f" % [
					Levels.number_of(i), truck.period, authored_period])
				bad += 1
			var n: int = Levels.number_of(i)
			var label := "L%d" % n if n > 0 else "id%d" % i
			if authored_amp > 0.0:
				var new_left := truck.base_x - truck.amp
				var new_right := truck.base_x + truck.amp
				if not is_equal_approx(new_left, old_left):
					print("CAB CLIP L%d: left extreme %.1f != original %.1f" % [
						n, new_left, old_left])
					bad += 1
				var expect_right := minf(old_right, max_x)
				if not is_equal_approx(new_right, expect_right):
					print("CAB CLIP L%d: right extreme %.1f != expected %.1f" % [
						n, new_right, expect_right])
					bad += 1
				if new_right > max_x + 0.01:
					print("CAB CLIP L%d (id %d): moving right extreme %.1f is past max %.1f" % [
						n, i, new_right, max_x])
					bad += 1
				if new_right + front_ext > Truck.VIEW_WIDTH + 0.01:
					print("CAB CLIP L%d (id %d): bumper at right extreme %.1f is past the view" % [
						n, i, new_right + front_ext])
					bad += 1
				if new_right + cab_right > Truck.VIEW_WIDTH + 0.01:
					print("CAB CLIP L%d (id %d): cab at right extreme %.1f is past the view" % [
						n, i, new_right + cab_right])
					bad += 1
				if old_right > max_x + 0.01:
					remapped += 1
					print("  remap %s %s: right %.0f -> %.0f (left %.0f unchanged, period %.1fs, dx %+.0f)" % [
						label, Levels.world_of(i).name, old_right, new_right, new_left,
						truck.period, new_right - old_right])
			else:
				if fitted > max_x + 0.01:
					print("CAB CLIP L%d (id %d): fitted x %.1f is past max %.1f" % [
						n, i, fitted, max_x])
					bad += 1
				var front: float = fitted + front_ext
				if front > Truck.VIEW_WIDTH + 0.01:
					print("CAB CLIP L%d (id %d): bumper at %.1f is past the view (%.0f)" % [
						n, i, front, Truck.VIEW_WIDTH])
					bad += 1
				if fitted + cab_right > Truck.VIEW_WIDTH + 0.01:
					print("CAB CLIP L%d (id %d): cab body at %.1f is past the view" % [
						n, i, fitted + cab_right])
					bad += 1
				if not is_equal_approx(authored, fitted):
					clamped += 1
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
	print("CAB CLIP CHECK: %d problem(s); parked-clamped %d, path-remapped %d of %d V0-truck configs (max bed x=%.0f)" % [
		bad, clamped, remapped, checked, max_x])
	quit(1 if bad else 0)
