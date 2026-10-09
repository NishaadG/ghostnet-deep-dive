class_name SlotSelect
extends Control
# Three save slots. An empty slot starts a new game; a used one shows progress and can be
# played or deleted (delete asks twice).

signal slot_chosen(slot: int, is_new: bool)
signal back_pressed

var _armed_delete := 0           # slot waiting for the second "really delete?" press


func _ready() -> void:
	size = Vector2(1280, 720)
	var scene := MenuScene.new()
	scene.dim = 0.45
	scene.show_diver = false
	add_child(scene)
	var title := UiKit.label("CHOOSE A SAVE", 44, true)
	title.position = Vector2(0, 50)
	title.size = Vector2(1280, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	_build_cards()
	var back := UiKit.button("BACK", Vector2(180, 50), Art.CYAN)
	back.position = Vector2(550, 640)
	back.pressed.connect(func(): back_pressed.emit())
	add_child(back)


func _build_cards() -> void:
	for slot in range(1, Game.SLOT_COUNT + 1):
		var data := Game.slot_summary(slot)
		var panel := UiKit.panel(Vector2(90 + (slot - 1) * 370, 140), Vector2(340, 460), Art.CYAN if data.is_empty() else Art.AMBER)
		add_child(panel)
		var heading := UiKit.label("SLOT %d" % slot, 26, true, Art.CYAN if data.is_empty() else Art.AMBER)
		heading.position = Vector2(24, 18)
		panel.add_child(heading)
		if data.is_empty():
			_empty_card(panel, slot)
		else:
			_used_card(panel, slot, data)


func _empty_card(panel: Panel, slot: int) -> void:
	var text := UiKit.label("Empty", 30, true, Color(Art.ICE, 0.5))
	text.position = Vector2(24, 150)
	panel.add_child(text)
	var hint := UiKit.label("Start a fresh dive log.", 16, false, Color(Art.ICE, 0.6))
	hint.position = Vector2(24, 196)
	panel.add_child(hint)
	var button := UiKit.button("NEW GAME", Vector2(292, 58), Art.CYAN, true)
	button.position = Vector2(24, 370)
	button.pressed.connect(func(): slot_chosen.emit(slot, true))
	panel.add_child(button)


func _used_card(panel: Panel, slot: int, data: Dictionary) -> void:
	var broken := 0
	var hp: Dictionary = data.get("wall_hp", {})
	for i in Balance.WALLS.size():
		if float(hp.get(str(i), Balance.WALLS[i]["hp"])) <= 0.0:
			broken += 1
	var rows := [
		["Dives", str(int(data.get("dives", 0)))],
		["Tags", str(int(data.get("tags", 0)))],
		["Best distance", "%d m" % int(float(data.get("best_distance", 0.0)))],
		["Net walls", "%d / %d torn" % [broken, Balance.WALLS.size()]],
		["Animals freed", str(int(data.get("animals_freed", 0)))],
	]
	for i in rows.size():
		var left := UiKit.label(rows[i][0], 17, false, Color(Art.ICE, 0.7))
		left.position = Vector2(24, 70 + i * 40)
		panel.add_child(left)
		var right := UiKit.label(rows[i][1], 19, true)
		right.position = Vector2(170, 68 + i * 40)
		panel.add_child(right)
	if bool(data.get("story_complete", false)):
		var badge := UiKit.label("THE LUMEN IS FREE", 16, true, Art.CYAN)
		badge.position = Vector2(24, 280)
		panel.add_child(badge)
	var saved := UiKit.label(String(data.get("saved_at", "")).replace("T", "  "), 13, false, Color(Art.ICE, 0.5))
	saved.position = Vector2(24, 318)
	panel.add_child(saved)
	var play := UiKit.button("PLAY", Vector2(292, 58), Art.AMBER, true)
	play.position = Vector2(24, 350)
	play.pressed.connect(func(): slot_chosen.emit(slot, false))
	panel.add_child(play)
	var delete := UiKit.button("DELETE", Vector2(292, 40), Art.MAGENTA, false, 16)
	delete.position = Vector2(24, 414)
	delete.pressed.connect(func(): _delete_pressed(slot, delete))
	panel.add_child(delete)


func _delete_pressed(slot: int, button: Button) -> void:
	if _armed_delete != slot:
		_armed_delete = slot
		button.text = "REALLY DELETE?  press again"
		return
	Game.delete_slot(slot)
	_armed_delete = 0
	for child in get_children():
		if child is Panel:
			child.queue_free()
	_build_cards()
