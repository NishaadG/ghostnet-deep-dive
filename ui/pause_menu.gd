class_name PauseMenu
extends Control
# The Esc menu. In a dive it pauses the game (and can abandon the dive); on any other screen it is
# a quick way to settings, the main menu or quitting. Esc again closes it. Works while the tree is paused.

signal resume_pressed
signal settings_pressed
signal quit_pressed            # abandon the dive (back to the workshop, no tags banked)
signal menu_pressed            # back to the title screen
signal exit_pressed            # quit the game (not shown in the web build)

var in_dive := true
var show_main_menu := true     # false on the title screen itself


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1280, 720)
	var shade := ColorRect.new()
	shade.color = Color(Art.INK, 0.7)
	shade.size = size
	add_child(shade)
	var entries := [["RESUME", Art.CYAN, true, resume_pressed], ["SETTINGS", Art.CYAN, false, settings_pressed]]
	if in_dive:
		entries.append(["ABANDON DIVE", Art.MAGENTA, false, quit_pressed])
	if show_main_menu:
		entries.append(["MAIN MENU", Art.CYAN, false, menu_pressed])
	if not OS.has_feature("web"):
		entries.append(["QUIT GAME", Art.MAGENTA, false, exit_pressed])
	var height := 150.0 + entries.size() * 68.0 + (40.0 if in_dive else 10.0)
	var top := 360.0 - height / 2.0
	add_child(UiKit.panel(Vector2(440, top), Vector2(400, height)))
	var title := UiKit.label("PAUSED" if in_dive else "MENU", 40, true)
	title.position = Vector2(440, top + 20)
	title.size = Vector2(400, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	for i in entries.size():
		var button := UiKit.button(entries[i][0], Vector2(300, 54), entries[i][1], entries[i][2], 21)
		button.position = Vector2(490, top + 100 + i * 68)
		button.pressed.connect(func(): (entries[i][3] as Signal).emit())
		add_child(button)
	if in_dive:
		var hint := UiKit.label("Abandoning ends the dive without banking any tags.", 13, false, Color(Art.ICE, 0.6))
		hint.position = Vector2(440, top + height - 40)
		hint.size = Vector2(400, 24)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		resume_pressed.emit()
		get_viewport().set_input_as_handled()
