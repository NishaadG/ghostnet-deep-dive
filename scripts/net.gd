class_name Net
extends Node2D
# A loose ghost net: a glowing mesh that sways. Touch it and it is cut into two halves
# that drift apart. If an animal is trapped inside, it swims free.
# The mesh is drawn by code every frame from a grid of points, so it can sway and split.

const COLUMNS := 8
const ROWS := 7

var radius := 70.0
var has_animal := false
var is_cut := false

var _size := Vector2(200, 240)
var _phase := randf() * TAU
var _age := 0.0
var _cut_t := 0.0                # 0 = whole, 1 = fully drifted apart and faded
var _animal: Animal


func setup(kind: int, with_animal: bool) -> void:
	var sizes := [Vector2(200, 250), Vector2(250, 300), Vector2(300, 340), Vector2(170, 220)]
	_size = sizes[kind % 4]
	radius = minf(_size.x, _size.y) * 0.38
	has_animal = with_animal
	if with_animal:
		_animal = Animal.new()
		_animal.setup("turtle" if kind == 1 or kind == 2 else "fish", 1.0 if kind == 1 or kind == 2 else 1.7)
		_animal.position = Vector2(0, -_size.y * 0.1)
		add_child(_animal)


func _process(delta: float) -> void:
	_age += delta
	if not is_cut:
		position.y += sin(_age * 0.5 + _phase) * 5.0 * delta           # slow drift
	queue_redraw()


func cut_open() -> void:
	is_cut = true
	_add_sparks()
	create_tween().tween_property(self, "_cut_t", 1.0, 0.9)
	if _animal:
		_animal.free_swim(Vector2(520, -260))
	get_tree().create_timer(1.7).timeout.connect(queue_free)


# A grid point of the mesh. Rows narrow toward the bottom, like a bag of net.
func _mesh_point(row: int, col: int) -> Vector2:
	var v := row / float(ROWS - 1)
	var u := col / float(COLUMNS - 1) * 2.0 - 1.0
	var width := _size.x * 0.5 * (0.75 + 0.45 * sin(v * PI * 0.9 + 0.2)) * (1.0 - v * 0.25)
	var sway := sin(_age * 1.2 + v * 2.2 + _phase) * 9.0 * v
	return Vector2(u * width + sway, -_size.y * 0.45 + v * _size.y * 0.75)


func _draw() -> void:
	var fade := 1.0 - _cut_t
	var mesh_color := Color(Art.NET_COLOR, 0.8 * fade)
	var knot_color := Color(Art.ICE, 0.9 * fade)
	Art.glow(self, Vector2.ZERO, _size.x * 0.75, Color(Art.CYAN, 0.12 * fade))
	var mid := COLUMNS / 2
	for row in ROWS:
		for col in COLUMNS:
			var p := _mesh_point(row, col) + _split_offset(col, mid)
			if col + 1 < COLUMNS and not (is_cut and col + 1 == mid):          # cut: no strand across the middle
				draw_line(p, _mesh_point(row, col + 1) + _split_offset(col + 1, mid), mesh_color, 1.6, true)
			if row + 1 < ROWS:
				draw_line(p, _mesh_point(row + 1, col) + _split_offset(col, mid), mesh_color, 1.6, true)
			draw_circle(p, 2.2, knot_color)
	# Floats along the top edge, and loose threads trailing from the bottom.
	for col in range(0, COLUMNS, 2):
		var top := _mesh_point(0, col) + _split_offset(col, mid)
		Art.glow(self, top, 14.0, Color(Art.AMBER, 0.5 * fade))
		draw_circle(top + Vector2(0, -4), 4.5, Color(Art.AMBER, fade))
	for col in range(1, COLUMNS - 1, 2):
		var start := _mesh_point(ROWS - 1, col) + _split_offset(col, mid)
		var thread := PackedVector2Array()
		for k in 6:
			thread.append(start + Vector2(sin(_age * 1.4 + k * 0.8 + col) * 7.0 * k * 0.5, k * 17.0))
		draw_polyline(thread, Color(Art.NET_COLOR, 0.45 * fade), 1.4, true)


# Left half drifts left and down, right half right and down.
func _split_offset(col: int, mid: int) -> Vector2:
	if _cut_t == 0.0:
		return Vector2.ZERO
	var side := -1.0 if col < mid else 1.0
	return Vector2(side * 90.0, 60.0) * _cut_t


func _add_sparks() -> void:
	var sparks := CPUParticles2D.new()
	sparks.emitting = true
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 24
	sparks.lifetime = 0.6
	sparks.spread = 180.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 120.0
	sparks.initial_velocity_max = 320.0
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 5.0
	sparks.color = Color(Art.CYAN.lightened(0.5), 0.95)
	sparks.material = Art.additive
	add_child(sparks)
