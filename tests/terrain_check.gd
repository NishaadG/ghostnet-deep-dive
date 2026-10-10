extends Node
# The cave must be a gradual descent: no steep walls, no big rises. Generates the trench for many seeds
# and checks the steepest drop and the steepest rise in every zone.
# Run: godot --headless --path . res://tests/terrain_check.tscn

const MAX_DROP_DEG := 40.0        # steepest allowed slope going down
const MAX_RISE_DEG := 10.0        # steepest allowed slope going UP (shelf wobble only)
const MAX_RISE_PX := 60.0         # the floor may never climb more than this over any 600 px


func _ready() -> void:
	var failures: Array[String] = []
	var steepest_drop := 0.0
	var steepest_rise := 0.0
	var worst_climb := 0.0
	for seed_value in range(1, 31):
		var terrain := Terrain.new()
		terrain.setup(seed_value)
		terrain.update(45000.0)                                   # about 4500 m, past every zone
		var points := terrain.points
		for i in points.size() - 1:
			var dx := points[i + 1].x - points[i].x
			var dy := points[i + 1].y - points[i].y              # positive = going down
			var degrees := rad_to_deg(atan2(dy, dx))
			steepest_drop = maxf(steepest_drop, degrees)
			steepest_rise = maxf(steepest_rise, -degrees)
		# the biggest net climb over any stretch of about 600 px
		for i in points.size():
			var j := i
			while j + 1 < points.size() and points[j].x - points[i].x < 600.0:
				j += 1
			worst_climb = maxf(worst_climb, points[i].y - points[j].y)
	print("steepest drop %.1f deg, steepest rise %.1f deg, biggest climb over 600 px: %.0f px" % [steepest_drop, steepest_rise, worst_climb])
	if steepest_drop > MAX_DROP_DEG:
		failures.append("a slope down is too steep (%.1f deg)" % steepest_drop)
	if steepest_rise > MAX_RISE_DEG:
		failures.append("the floor rises too steeply (%.1f deg)" % steepest_rise)
	if worst_climb > MAX_RISE_PX:
		failures.append("the floor climbs %.0f px over a short stretch" % worst_climb)
	for f in failures:
		printerr("TERRAIN FAIL: ", f)
	print("TERRAIN ", "FAIL" if failures else "OK")
	get_tree().quit(1 if failures else 0)
