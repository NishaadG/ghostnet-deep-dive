class_name Terrain
extends Node2D
# The trench: a floor polyline built as a staircase (shelf, then drop, then shelf...).
# The ceiling is the same line moved up by the corridor height. Both are looked up by x,
# so collision is just "is Nova below floor_y(x)?". Nothing is stored for the ceiling.
# Scenery (corals, towers, crystals) is a list of small records drawn only near the camera.

var points := PackedVector2Array()   # floor polyline, x ascending
var decor: Array[Dictionary] = []    # {kind, x, y, size, seed, variant, up, width}
var trick_zones: Array[Dictionary] = []   # {id, kind ("drop"), x0, x1, y0, y1}: long slopes worth a clean-pass bonus
var _zone_id := 0
var view_x := 0.0
var view_half := 1100.0              # half the visible width in world px
var all_lit := false                 # true after the Lumen is freed: every coral glows
var time := 0.0
var rng := RandomNumberGenerator.new()
var _decor_id := 0


func setup(seed_value: int) -> void:
	rng.seed = seed_value
	points = PackedVector2Array([Vector2(-3000, Balance.START_FLOOR), Vector2(0, Balance.START_FLOOR)])
	decor.clear()
	trick_zones.clear()


# Called every frame by the run: build ahead of the camera, forget what is far behind.
func update(camera_x: float, delta := 0.0) -> void:
	view_x = camera_x
	time += delta
	while points[points.size() - 1].x < camera_x + Balance.TERRAIN_AHEAD:
		_add_step()
	while points.size() > 3 and points[1].x < camera_x - Balance.TERRAIN_BEHIND:
		points.remove_at(0)
	while not decor.is_empty() and decor[0]["x"] < camera_x - Balance.TERRAIN_BEHIND:
		decor.pop_front()
	while not trick_zones.is_empty() and trick_zones[0]["x1"] < camera_x - Balance.TERRAIN_BEHIND:
		trick_zones.pop_front()
	queue_redraw()


func floor_y(x: float) -> float:
	var i := _segment_index(x)
	var a := points[i]
	var b := points[i + 1]
	return lerpf(a.y, b.y, clampf(inverse_lerp(a.x, b.x, x), 0.0, 1.0))


func ceiling_y(x: float) -> float:
	return floor_y(x) - Balance.corridor_at(x)


# Binary search for the segment that contains x.
func _segment_index(x: float) -> int:
	var low := 0
	var high := points.size() - 2
	while low < high:
		var mid := (low + high + 1) / 2
		if points[mid].x <= x:
			low = mid
		else:
			high = mid - 1
	return low


# ---- Generation: each zone has its own recipe for one "step" ----
# A step is a nearly flat shelf followed by a gradual slope DOWN. The floor never rises more than a few
# pixels and never drops steeper than about 36 degrees, so the cave always reads as one long descent.

func _add_step() -> void:
	var first_new := points.size() - 1
	var x: float = points[points.size() - 1].x
	var zone: String = Balance.ZONES[Balance.zone_index_at(x)]["id"]
	if zone == "abyss":
		zone = ["reef", "city", "slope", "trench"][rng.randi() % 4]
	match zone:
		"reef":    # gentle shelf, small gradual step
			_shelf(rng.randf_range(350, 600), 8.0)
			_descend(rng.randf_range(50, 110), 8.0, 12.0)
		"city":    # a drowned tower's flat roof, then a gradual slope down to the next, lower roof
			_shelf(rng.randf_range(300, 700), 0.0)
			var roof_start := points[first_new]
			var roof_end: Vector2 = points[points.size() - 1]
			_add_decor("tower", roof_start.x, roof_start.y, 0.0, roof_end.x - roof_start.x, false)
			_descend(rng.randf_range(200, 450), 14.0, 20.0)
		"slope":   # rock ledge, then a long gradual slope down
			_shelf(rng.randf_range(500, 900), 10.0)
			_descend(rng.randf_range(1200, 2500), 20.0, 28.0)
		"trench":  # short ledge, then a very long gradual slope down
			_shelf(rng.randf_range(250, 450), 6.0)
			_descend(rng.randf_range(2500, 4500), 24.0, 32.0)
	_decorate(first_new, zone)


# In the endless Abyss, descents grow 5% every 500 m.
func _drop_scale(x: float) -> float:
	var past_abyss_m := x / Balance.PX_PER_M - Balance.ZONES[4]["start_m"]
	return pow(1.05, maxf(0.0, floorf(past_abyss_m / 500.0)))


# A nearly flat stretch. Each piece changes height by only a few pixels, so there are no sudden bumps.
func _shelf(length: float, bumpiness: float) -> void:
	var start: Vector2 = points[points.size() - 1]
	var pieces := maxi(1, int(length / 180.0))
	var y := start.y
	for i in range(1, pieces + 1):
		y += rng.randf_range(-bumpiness, bumpiness) * 0.35
		y = clampf(y, start.y - bumpiness, start.y + bumpiness)
		points.append(Vector2(start.x + length * i / pieces, y))


# A gradual slope down by `height` px at an average of `min_deg` to `max_deg` degrees. The ends are eased so
# the lip and the base are rounded, and the steepest part is only about 20% steeper than the average.
func _descend(height: float, min_deg: float, max_deg: float) -> void:
	var start: Vector2 = points[points.size() - 1]
	var total := height * _drop_scale(start.x)
	var width := total / tan(deg_to_rad(rng.randf_range(min_deg, max_deg)))
	var pieces := maxi(3, int(width / 280.0))
	for i in range(1, pieces + 1):
		var t := float(i) / pieces
		var eased := t * 0.6 + 0.4 * smoothstep(0.0, 1.0, t)
		points.append(Vector2(start.x + width * t, start.y + total * eased))
	if total >= 250.0:
		_add_zone("drop", start, points[points.size() - 1])


# Scatter scenery on the segments of the step we just built.
func _decorate(first_point: int, zone: String) -> void:
	for i in range(first_point, points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var length := b.x - a.x
		var flat: bool = absf(b.y - a.y) < 40.0 and length > 90.0
		if not flat:
			continue
		var x := rng.randf_range(a.x + 30.0, maxf(a.x + 31.0, b.x - 30.0))
		var y := lerpf(a.y, b.y, inverse_lerp(a.x, b.x, x))
		match zone:
			"reef":
				if rng.randf() < 0.75:
					_add_decor("coral", x, y, rng.randf_range(90, 170), 0.0, false)
				if rng.randf() < 0.4:
					_add_decor("fan", x + 90.0, y, rng.randf_range(70, 120), 0.0, false)
			"slope":
				if rng.randf() < 0.7:
					_add_decor("spikes", x, y, rng.randf_range(120, 220), 0.0, false)
				if rng.randf() < 0.6:
					_add_decor("spikes", x + 60.0, y - Balance.corridor_at(x), rng.randf_range(100, 200), 0.0, true)
			"trench":
				if rng.randf() < 0.6:
					_add_decor("crystals", x, y, rng.randf_range(100, 200), 0.0, false)
				if rng.randf() < 0.4:
					_add_decor("vent", x + 80.0, y, rng.randf_range(120, 220), 0.0, false)
				if rng.randf() < 0.5:
					_add_decor("crystals", x - 40.0, y - Balance.corridor_at(x), rng.randf_range(90, 160), 0.0, true)
			"city":
				if rng.randf() < 0.3:
					_add_decor("fan", x, y, rng.randf_range(60, 100), 0.0, false)


# Remember a long slope so the run can award a bonus for flying down it without touching rock.
func _add_zone(kind: String, from: Vector2, to: Vector2) -> void:
	_zone_id += 1
	trick_zones.append({"id": _zone_id, "kind": kind, "x0": from.x, "x1": to.x, "y0": from.y, "y1": to.y})


func _add_decor(kind: String, x: float, y: float, size: float, width: float, hanging: bool) -> void:
	_decor_id += 1
	decor.append({"kind": kind, "x": x, "y": y, "size": size, "width": width, "hanging": hanging,
			"seed": _decor_id * 7 + 3, "variant": _decor_id % 10})


# ---- Drawing: only what is near the camera ----

func _draw() -> void:
	var x_min := view_x - view_half
	var x_max := view_x + view_half
	var palette := Art.zone_palette(view_x)
	var rock: Color = palette["rock"]
	var accent: Color = palette["accent"]
	var top_color := rock.lerp(accent, 0.14).lightened(0.05)
	var mid_color := rock
	var deep_color := rock.darkened(0.55)
	var ceil_top := rock.darkened(0.5)
	var floor_edge := PackedVector2Array()
	var ceiling_edge := PackedVector2Array()
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		if b.x < x_min:
			continue
		if a.x > x_max:
			break
		# Floor: lit near the edge, fading to dark rock below.
		var fade := 700.0
		draw_primitive(PackedVector2Array([a, b, b + Vector2(0, fade), a + Vector2(0, fade)]),
				PackedColorArray([top_color, top_color, mid_color, mid_color]), PackedVector2Array())
		draw_primitive(PackedVector2Array([a + Vector2(0, fade), b + Vector2(0, fade), Vector2(b.x, maxf(a.y, b.y) + 4000.0), Vector2(a.x, maxf(a.y, b.y) + 4000.0)]),
				PackedColorArray([mid_color, mid_color, deep_color, deep_color]), PackedVector2Array())
		if floor_edge.is_empty() or floor_edge[floor_edge.size() - 1] != a:
			floor_edge.append(a)
		floor_edge.append(b)
		# Ceiling: only where it is below the surface. draw_primitive tolerates zero-thickness pieces.
		var ca := maxf(a.y - Balance.corridor_at(a.x), 0.0)
		var cb := maxf(b.y - Balance.corridor_at(b.x), 0.0)
		if ca > 1.0 or cb > 1.0:
			var top_a := ca - clampf(ca, 0.0, 1800.0)
			var top_b := cb - clampf(cb, 0.0, 1800.0)
			draw_primitive(PackedVector2Array([Vector2(a.x, top_a), Vector2(b.x, top_b), Vector2(b.x, cb), Vector2(a.x, ca)]),
					PackedColorArray([deep_color, deep_color, ceil_top, ceil_top]), PackedVector2Array())
			if ceiling_edge.is_empty() or ceiling_edge[ceiling_edge.size() - 1] != Vector2(a.x, ca):
				ceiling_edge.append(Vector2(a.x, ca))
			ceiling_edge.append(Vector2(b.x, cb))
	_draw_strata(floor_edge, rock, accent)
	var dark: float = palette["dark"]
	_draw_glow_line(floor_edge, accent, 1.0 + dark * 0.8)          # brighter edges in dark water, so slopes stay readable
	_draw_glow_line(ceiling_edge, accent, 0.5 + dark * 0.6)
	_draw_decor(x_min, x_max, palette)


# Faint parallel lines under the edge give the rock layered depth.
func _draw_strata(edge: PackedVector2Array, rock: Color, accent: Color) -> void:
	if edge.size() < 2:
		return
	for k in 3:
		var shifted := PackedVector2Array()
		for p in edge:
			shifted.append(p + Vector2(0, 38.0 + k * 52.0))
		draw_polyline(shifted, Color(accent, 0.07 - k * 0.015), 2.0, true)


# A soft wide halo, a medium glow and a bright thin core: reads as a lit edge.
func _draw_glow_line(line: PackedVector2Array, accent: Color, strength: float) -> void:
	if line.size() < 2:
		return
	draw_polyline(line, Color(accent, 0.10 * strength), 16.0, true)
	draw_polyline(line, Color(accent, 0.28 * strength), 7.0, true)
	draw_polyline(line, Color(accent.lightened(0.4), 0.9 * strength), 2.4, true)


func _draw_decor(x_min: float, x_max: float, palette: Dictionary) -> void:
	var accent: Color = palette["accent"]
	var rock: Color = palette["rock"]
	var lights := mini(Game.reef_lights(), 10)
	for d in decor:
		var x: float = d["x"]
		if x < x_min - 200.0 or x > x_max + 200.0:
			continue
		var pos := Vector2(x, d["y"])
		match d["kind"]:
			"coral":
				var lit: bool = all_lit or int(d["variant"]) < lights
				DecorArt.coral(self, pos, d["size"], d["seed"], d["variant"], lit, time)
			"fan":
				DecorArt.sea_fan(self, pos, d["size"], d["seed"], accent, time)
			"tower":
				DecorArt.tower(self, pos, d["width"], 1300.0, d["seed"], rock.lightened(0.08), accent)
			"spikes":
				DecorArt.spikes(self, pos, d["size"], d["seed"], rock.lightened(0.1), accent, not d["hanging"])
			"crystals":
				DecorArt.crystals(self, pos, d["size"], d["seed"], accent, not d["hanging"], time)
			"vent":
				DecorArt.vent(self, pos, d["size"], d["seed"], accent, time)
