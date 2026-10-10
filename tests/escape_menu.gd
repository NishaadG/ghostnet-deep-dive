extends Node
# Headless check of the Esc menu: it opens on every screen (pausing only a dive), sits above the dive,
# closes with Esc again, and its buttons lead where they say. Uses throwaway saves.
# Run: godot --headless --path . res://tests/escape_menu.tscn

var failures: Array[String] = []
var main: Node


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _esc() -> void:
	var event := InputEventAction.new()
	event.action = "pause"
	event.pressed = true
	get_viewport().push_input(event)
	await get_tree().process_frame


func _menu() -> PauseMenu:
	if main._overlay is CanvasLayer and (main._overlay as CanvasLayer).get_child(0) is PauseMenu:
		return (main._overlay as CanvasLayer).get_child(0)
	return null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.save_enabled = false
	Game.save_dir = "user://test_"
	Game.new_game(1)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	for screen in ["title", "workshop"]:
		if screen == "workshop":
			main.show_workshop()
		await get_tree().process_frame
		await _esc()
		check(_menu() != null and not _menu().in_dive, "Esc opens the menu on the %s" % screen)
		check(not get_tree().paused, "the menu does not pause the %s" % screen)
		await _esc()
		await get_tree().process_frame
		check(main._overlay == null, "Esc again closes the menu on the %s" % screen)
	Game.seen_scenes.append("wall0_meet")               # keep the dive free of story pauses for this test
	main.start_run()
	await get_tree().process_frame
	await _esc()
	check(_menu() != null and _menu().in_dive and get_tree().paused, "Esc in a dive pauses it")
	check((main._overlay as CanvasLayer).layer > 10, "the menu draws above the dive's HUD and darkness")
	_menu().menu_pressed.emit()
	await get_tree().process_frame
	check(main._screen is Title and not get_tree().paused, "MAIN MENU goes to the title and unpauses")
	main.start_run()
	await get_tree().process_frame
	await _esc()
	_menu().quit_pressed.emit()
	await get_tree().process_frame
	check(main._screen is Workshop, "ABANDON DIVE goes to the workshop")
	get_tree().paused = false
	for f in failures:
		printerr("ESCAPE MENU FAIL: ", f)
	print("ESCAPE MENU %s" % ("FAIL" if failures else "OK"))
	get_tree().quit(1 if failures else 0)
