extends Node
# Opens the debug panel on several screens of the real game and presses every button, timing each press,
# to find a hang. Run in a real window: godot --path . res://tests/panel_probe.tscn
var frame := 0
var main: Node
var buttons: Array[Button] = []
var stage := 0
var started := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS          # keep ticking even when a scene pauses the dive
	Game.save_enabled = false
	Game.new_game(1)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)


func _press_key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)


func _collect(node: Node) -> void:
	if node is Button:
		buttons.append(node)
	for child in node.get_children():
		_collect(child)


func _process(_delta: float) -> void:
	frame += 1
	match stage:
		0:
			if frame == 15:
				print("== opening panel on the TITLE screen (", Debug.screen_name(), ")")
				_press_key(KEY_F9)
				stage = 1
				frame = 0
		1:
			if frame == 20:
				print("   panel open, running 20 frames fine; closing")
				_press_key(KEY_F9)
				stage = 2
				frame = 0
		2:
			if frame == 10:
				Debug.go("workshop")
			if frame == 25:
				print("== opening panel on the WORKSHOP (", Debug.screen_name(), ")")
				_press_key(KEY_F9)
				stage = 3
				frame = 0
		3:
			if frame == 20:
				print("   workshop ok; closing, starting dive")
				_press_key(KEY_F9)
				stage = 4
				frame = 0
		4:
			if frame == 10:
				Debug.go("dive")
			if frame == 40:
				print("== opening panel in the DIVE")
				_press_key(KEY_F9)
				stage = 5
				frame = 0
		5:
			if frame == 20:
				buttons.clear()
				_collect(get_tree().root.get_child(get_tree().root.get_child_count() - 1))
				print("   panel buttons: ", buttons.size())
				stage = 6
				frame = 0
		6:
			if frame % 4 == 0:
				if buttons.is_empty():
					print("PROBE DONE: no hang")
					get_tree().quit()
					return
				var b: Button = buttons.pop_front()
				if is_instance_valid(b) and b.is_inside_tree() and not (b.text in ["Title", "Workshop", "Reset slot", "Switch to REAL game"]):
					var t0 := Time.get_ticks_msec()
					print("press: ", b.text.replace("\n", " "))
					b.pressed.emit()
					get_tree().paused = false               # a wall scene may have paused the dive; carry on
					var ms := Time.get_ticks_msec() - t0
					if ms > 500:
						print("   !! that press took ", ms, " ms")
