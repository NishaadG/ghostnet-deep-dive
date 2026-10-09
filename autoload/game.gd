extends Node
# Global state shared by every screen: upgrade levels now, tags/save in milestone 3.

var levels := {}   # upgrade id -> level; a missing id means level 0


func _ready() -> void:
	_setup_input()


func level(id: String) -> int:
	return levels.get(id, 0)


# Input actions are created here (not in project.godot) so the keys are easy to read and change.
func _setup_input() -> void:
	_bind("tilt_up", [KEY_A, KEY_LEFT])
	_bind("tilt_down", [KEY_D, KEY_RIGHT])
	_bind("thrust", [KEY_SPACE])
	_bind("pause", [KEY_ESCAPE])
	_bind("confirm", [KEY_ENTER, KEY_KP_ENTER])


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
