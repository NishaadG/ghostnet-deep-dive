class_name PauseMenu
extends Control
# Esc during a dive. Keeps working while the game tree is paused.

signal resume_pressed
signal settings_pressed
signal quit_pressed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1280, 720)
	var shade := ColorRect.new()
	shade.color = Color(Art.INK, 0.7)
	shade.size = size
	add_child(shade)
	add_child(UiKit.panel(Vector2(440, 170), Vector2(400, 380)))
	var title := UiKit.label("PAUSED", 40, true)
	title.position = Vector2(440, 190)
	title.size = Vector2(400, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var entries := [["RESUME", Art.CYAN, true, resume_pressed], ["SETTINGS", Art.CYAN, false, settings_pressed], ["ABANDON DIVE", Art.MAGENTA, false, quit_pressed]]
	for i in entries.size():
		var button := UiKit.button(entries[i][0], Vector2(300, 56), entries[i][1], entries[i][2], 22)
		button.position = Vector2(490, 270 + i * 76)
		button.pressed.connect(func(): (entries[i][3] as Signal).emit())
		add_child(button)
	var hint := UiKit.label("Abandoning ends the dive without banking any tags.", 13, false, Color(Art.ICE, 0.6))
	hint.position = Vector2(440, 506)
	hint.size = Vector2(400, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		resume_pressed.emit()
		get_viewport().set_input_as_handled()
