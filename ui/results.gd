class_name Results
extends Control
# After a dive: numbers count up one by one and turn into tags, then the line that
# must always appear: what you cut against what the fleet cut loose.

signal continue_pressed

var result: Dictionary
var _rows: Array[Dictionary] = []
var _skipped := false
var _done := false
var _tween: Tween
var _total_label: Label
var _fleet_label: Label
var _hint: Label
var _wall_layer: Control


func _ready() -> void:
	size = Vector2(1280, 720)
	var scene := MenuScene.new()
	scene.dim = 0.55
	scene.show_diver = false
	add_child(scene)
	add_child(UiKit.panel(Vector2(190, 36), Vector2(900, 648), Art.CYAN, 0.7))
	add_child(_label("DIVE %d" % Game.dives, Vector2(230, 52), 22, true, Art.CYAN))
	add_child(_label("Dive complete", Vector2(230, 76), 44, true, Art.ICE))
	add_child(_label(_reason_text(), Vector2(230, 134), 18, false, Color(Art.ICE, 0.75)))

	var r := result
	_add_row("Distance", "%d m", r["distance_m"], int(r["distance_m"] / 20.0), "1 tag per 20 m")
	_add_row("Max depth", "%d m", r["max_depth_m"], int(r["max_depth_m"] / 20.0), "1 tag per 20 m")
	_add_row("Top speed", "%d px/s", r["top_speed"], -1, "")
	_add_row("Nets cut", "%d", r["nets_cut"], int(r["nets_cut"]), "1 tag each")
	_add_row("Animals freed", "%d", r["animals_freed"], 3 * int(r["animals_freed"]), "3 tags each")
	if int(r["wall_bonus"]) > 0:
		_add_row("Net wall torn", "%d", 1, int(r["wall_bonus"]), "bonus")

	_total_label = _label("", Vector2(230, 470), 36, true, Art.AMBER)
	add_child(_total_label)
	_fleet_label = _label("You cut %d nets. The fleet cut loose %d while you were down." % [r["nets_cut"], r["fleet_cut"]],
			Vector2(230, 530), 26, true, Color("ff8a8a"))
	_fleet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fleet_label.size = Vector2(820, 80)
	_fleet_label.modulate.a = 0.0
	add_child(_fleet_label)
	_hint = _label("Press Enter to continue", Vector2(230, 628), 18, false, Art.CYAN)
	_hint.modulate.a = 0.0
	add_child(_hint)
	_wall_layer = Control.new()
	_wall_layer.size = size
	_wall_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wall_layer.draw.connect(_draw_wall_progress)
	_wall_layer.modulate.a = 0.0
	add_child(_wall_layer)
	_reveal()


func _reason_text() -> String:
	return {
		"oxygen": "Oxygen ran out. Pip towed you up.",
		"crash": "You hit the seabed too hard. Pip towed you up.",
		"rest": "You came to rest on the seabed. Pip towed you up.",
		"wall": "A net wall stopped you. Pip towed you up.",
		"lumen": "The Lumen is free.",
	}.get(result["reason"], "Pip towed you up.")


func _add_row(title: String, format: String, value: float, tag_value: int, note: String) -> void:
	var y := 176.0 + _rows.size() * 48.0
	var name_label := _label(title, Vector2(230, y), 24, false)
	var value_label := _label("", Vector2(520, y), 24, true)
	var note_label := _label(note, Vector2(700, y + 6), 14, false, Color(Art.ICE, 0.5))
	var tag_label := _label("", Vector2(930, y), 24, true, Art.AMBER)
	for l in [name_label, value_label, note_label, tag_label]:
		l.modulate.a = 0.0
		add_child(l)
	_rows.append({"name": name_label, "value": value_label, "note": note_label, "tags": tag_label,
			"format": format, "target": value, "tag_value": tag_value})


# Rows appear one at a time; the number counts up, then its tags count up.
func _reveal() -> void:
	var total := 0
	for row in _rows:
		for key in ["name", "value", "note", "tags"]:
			(row[key] as Label).modulate.a = 1.0
		Audio.play("click", -10.0, 1.4)
		await _count(row["target"], 0.5, func(v: float): (row["value"] as Label).text = row["format"] % v)
		if row["tag_value"] >= 0:
			await _count(float(row["tag_value"]), 0.3, func(v: float): (row["tags"] as Label).text = "+%d" % int(v))
			total += row["tag_value"]
			_total_label.text = "Tags this dive: %d" % total
		await _pause(0.1)
	_total_label.text = "Tags this dive: %d      (you now have %d)" % [result["tags"], Game.tags]
	await _pause(0.3)
	_fleet_label.modulate.a = 1.0
	_wall_layer.modulate.a = 1.0
	_hint.modulate.a = 1.0
	_done = true


func _count(to_value: float, seconds: float, setter: Callable) -> void:
	_tween = create_tween()
	_tween.tween_method(setter, 0.0, to_value, 0.001 if _skipped else seconds)
	await _tween.finished


func _pause(seconds: float) -> void:
	if not _skipped:
		await get_tree().create_timer(seconds).timeout


# If a wall stopped the run, show how much of it is left: progress even when you failed.
func _draw_wall_progress() -> void:
	var info: Dictionary = result.get("wall_info", {})
	if info.is_empty():
		return
	var left: float = float(info["after"]) / float(info["max"])
	var bar := Rect2(700, 600, 340, 16)
	_wall_layer.draw_string(Game.font_bold, Vector2(700, 592), "%s: %d%% left" % [info["name"], int(left * 100.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Art.MAGENTA)
	_wall_layer.draw_rect(bar, Color(1, 1, 1, 0.1))
	_wall_layer.draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), Art.MAGENTA)
	var before: float = float(info["before"]) / float(info["max"])
	_wall_layer.draw_rect(Rect2(bar.position + Vector2(bar.size.x * left, 0), Vector2(bar.size.x * (before - left), bar.size.y)), Color(Art.AMBER, 0.8))
	_wall_layer.draw_rect(bar, Color(1, 1, 1, 0.5), false, 1.5)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("confirm"):
		return
	if _done:
		continue_pressed.emit()
	else:
		_skipped = true                       # first press just finishes the count-up
		if _tween:
			_tween.set_speed_scale(1000.0)


func _label(text: String, pos: Vector2, size_px: int, bold := false, color := Art.ICE) -> Label:
	var label := UiKit.label(text, size_px, bold, color)
	label.position = pos
	return label
