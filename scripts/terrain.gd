class_name Terrain
extends Node2D
# The trench: a floor polyline built as a staircase (shelf, then drop, then shelf...).
# The ceiling is the same line moved up by the corridor height. Both are looked up by x,
# so collision is just "is Nova below floor_y(x)?". Nothing is stored for the ceiling.

const SHEER := 90.0   # horizontal width of a "sheer" wall, so the slope is steep but never vertical

var points := PackedVector2Array()   # floor polyline, x ascending
var view_x := 0.0
var view_half := 1100.0              # half the visible width in world px
var floor_color := Color(0.12, 0.2, 0.26)
var edge_color := Color(0.4, 0.75, 0.8)
var rng := RandomNumberGenerator.new()


func setup(seed_value: int) -> void:
	rng.seed = seed_value
	points = PackedVector2Array([Vector2(-3000, Balance.START_FLOOR), Vector2(0, Balance.START_FLOOR)])


# Called every frame by the run: build ahead of the camera, forget what is far behind.
func update(camera_x: float) -> void:
	view_x = camera_x
	while points[points.size() - 1].x < camera_x + Balance.TERRAIN_AHEAD:
		_add_step()
	while points.size() > 3 and points[1].x < camera_x - Balance.TERRAIN_BEHIND:
		points.remove_at(0)
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

func _add_step() -> void:
	var x: float = points[points.size() - 1].x
	var zone: String = Balance.ZONES[Balance.zone_index_at(x)]["id"]
	if zone == "abyss":
		zone = ["reef", "city", "slope", "trench"][rng.randi() % 4]
	match zone:
		"reef":    # gentle shelf, small step
			_shelf(rng.randf_range(350, 600), 10.0)
			_drop(rng.randf_range(50, 110), 140.0)
		"city":    # flat roof, street canyon, next roof a little lower
			_shelf(rng.randf_range(300, 700), 0.0)
			var depth := rng.randf_range(250, 500)
			var lower := rng.randf_range(100, 250)
			_drop(depth, SHEER)
			_shelf(rng.randf_range(600, 1500), 15.0)
			var y: float = points[points.size() - 1].y
			points.append(Vector2(points[points.size() - 1].x + SHEER, y - depth + lower))
		"slope":   # rock ledge, then a big drop
			_shelf(rng.randf_range(500, 900), 25.0)
			_drop(rng.randf_range(1200, 2500), 150.0)
		"trench":  # short ledge, then a very long drop
			_shelf(rng.randf_range(250, 450), 10.0)
			_drop(rng.randf_range(2500, 4500), 170.0)


# In the endless Abyss, drops grow 5% every 500 m.
func _drop_scale(x: float) -> float:
	var past_abyss_m := x / Balance.PX_PER_M - Balance.ZONES[4]["start_m"]
	return pow(1.05, maxf(0.0, floorf(past_abyss_m / 500.0)))


func _shelf(length: float, bumpiness: float) -> void:
	var start: Vector2 = points[points.size() - 1]
	var pieces := maxi(1, int(length / 110.0))
	for i in range(1, pieces + 1):
		var wobble := rng.randf_range(-bumpiness, bumpiness) if i < pieces else 0.0
		points.append(Vector2(start.x + length * i / pieces, start.y + wobble))


func _drop(height: float, width: float) -> void:
	var last: Vector2 = points[points.size() - 1]
	points.append(Vector2(last.x + width, last.y + height * _drop_scale(last.x)))


# ---- Drawing: quads between neighbouring points, only those near the camera ----

func _draw() -> void:
	var x_min := view_x - view_half
	var x_max := view_x + view_half
	var floor_colors := PackedColorArray([floor_color, floor_color, floor_color, floor_color])
	var ceiling_color := floor_color.darkened(0.25)
	var ceiling_colors := PackedColorArray([ceiling_color, ceiling_color, ceiling_color, ceiling_color])
	var edge := PackedVector2Array()
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		if b.x < x_min:
			continue
		if a.x > x_max:
			break
		var bottom := maxf(a.y, b.y) + 3000.0
		draw_primitive(PackedVector2Array([a, b, Vector2(b.x, bottom), Vector2(a.x, bottom)]), floor_colors, PackedVector2Array())
		edge.append(a)
		edge.append(b)
		# draw_primitive (not a polygon) so zero-thickness ceiling pieces near the surface are harmless.
		var ca := maxf(a.y - Balance.corridor_at(a.x), 0.0)
		var cb := maxf(b.y - Balance.corridor_at(b.x), 0.0)
		if ca > 1.0 or cb > 1.0:
			var top_a := ca - clampf(ca, 0.0, 1500.0)
			var top_b := cb - clampf(cb, 0.0, 1500.0)
			draw_primitive(PackedVector2Array([Vector2(a.x, top_a), Vector2(b.x, top_b), Vector2(b.x, cb), Vector2(a.x, ca)]), ceiling_colors, PackedVector2Array())
			draw_line(Vector2(a.x, ca), Vector2(b.x, cb), edge_color.darkened(0.3), 3.0)
	for i in range(0, edge.size(), 2):
		draw_line(edge[i], edge[i + 1], edge_color, 4.0)
