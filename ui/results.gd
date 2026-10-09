class_name Results
extends Control
# After a dive: numbers count up one by one and turn into tags, then the line that
# must always appear: what you cut against what the fleet cut loose.

signal continue_pressed

var result: Dictionary
var _rows: Array[Dictionary] = []
var _row_labels: Array[Label] = []
var _skipped := false
var _done := false
var _tween: Tween
var _total_label: Label
var _fleet_label: Label
var _hint: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.07, 0.12, 0.94)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var portrait := TextureRect.new()
	var good: bool = result["tags"] >= 15
	portrait.texture = load("res://assets/sprites/nova_bust_smile.png" if good else "res://assets/sprites/nova_bust.png")
	portrait.position = Vector2(30, 230)
	portrait.custom_minimum_size = Vector2(380, 400)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size = Vector2(380, 400)
	add_child(portrait)

	_label("Dive %d complete" % (Game.dives), Vector2(450, 36), 40, Game.font_bold)
	_label(_reason_text(), Vector2(450, 92), 20, Game.font, Color(0.7, 0.85, 0.95))

	# Each row: name, raw number, tags earned from it.
	var r := result
	_add_row("Distance", "%d m", r["distance_m"], int(r["distance_m"] / 10.0))
	_add_row("Max depth", "%d m", r["max_depth_m"], int(r["max_depth_m"] / 10.0))
	_add_row("Top speed", "%d px/s", r["top_speed"], -1)
	_add_row("Nets cut", "%d", r["nets_cut"], int(r["nets_cut"]))
	_add_row("Animals freed", "%d", r["animals_freed"], 3 * int(r["animals_freed"]))
	if int(r["wall_bonus"]) > 0:
		_add_row("Net wall bonus", "%d", r["wall_bonus"], int(r["wall_bonus"]))

	_total_label = _label("", Vector2(450, 470), 34, Game.font_bold, Color(1.0, 0.85, 0.3))
	_fleet_label = _label("You cut %d nets. The fleet cut loose %d while you were down." % [r["nets_cut"], r["fleet_cut"]],
			Vector2(450, 535), 26, Game.font_bold, Color(1.0, 0.6, 0.55))
	_fleet_label.size = Vector2(780, 90)
	_fleet_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_fleet_label.modulate.a = 0.0
	_hint = _label("Press Enter to continue", Vector2(450, 650), 20, Game.font, Color(0.8, 0.9, 1.0))
	_hint.modulate.a = 0.0
	_reveal()


func _reason_text() -> String:
	return {
		"oxygen": "Oxygen ran out. Pip towed you up.",
		"crash": "You hit the seabed too hard. Pip towed you up.",
		"rest": "You came to rest on the seabed. Pip towed you up.",
		"wall": "A net wall stopped you. Pip towed you up.",
	}.get(result["reason"], "Pip towed you up.")


func _add_row(title: String, format: String, value: float, tag_value: int) -> void:
	var y := 150.0 + _rows.size() * 50.0
	var name_label := _label(title, Vector2(450, y), 26, Game.font)
	var value_label := _label("", Vector2(700, y), 26, Game.font_bold)
	var tag_label := _label("", Vector2(960, y), 26, Game.font_bold, Color(1.0, 0.85, 0.3))
	for l in [name_label, value_label, tag_label]:
		l.modulate.a = 0.0
	_rows.append({"name": name_label, "value": value_label, "tags": tag_label,
			"format": format, "target": value, "tag_value": tag_value})


# Rows appear one at a time; the number counts up, then its tags count up.
func _reveal() -> void:
	var total := 0
	for row in _rows:
		for key in ["name", "value", "tags"]:
			(row[key] as Label).modulate.a = 1.0
		await _count(row["target"], 0.5, func(v: float): (row["value"] as Label).text = row["format"] % v)
		if row["tag_value"] >= 0:
			await _count(float(row["tag_value"]), 0.3, func(v: float): (row["tags"] as Label).text = "+%d" % int(v))
			total += row["tag_value"]
			_total_label.text = "Tags this dive: %d" % total
		await _pause(0.12)
	_total_label.text = "Tags this dive: %d    (total %d)" % [result["tags"], Game.tags]
	await _pause(0.3)
	_fleet_label.modulate.a = 1.0
	_hint.modulate.a = 1.0
	_done = true


func _count(to_value: float, seconds: float, setter: Callable) -> void:
	_tween = create_tween()
	_tween.tween_method(setter, 0.0, to_value, 0.001 if _skipped else seconds)
	await _tween.finished


func _pause(seconds: float) -> void:
	if not _skipped:
		await get_tree().create_timer(seconds).timeout


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("confirm"):
		return
	if _done:
		continue_pressed.emit()
	else:
		_skipped = true                       # first press just finishes the count-up
		if _tween:
			_tween.set_speed_scale(1000.0)


func _label(text: String, pos: Vector2, size_px: int, font: Font, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label
