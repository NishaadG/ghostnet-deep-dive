class_name StoryCards
extends Control
# Short text cards over the animated reef: the intro for a new game and the ending after the
# Lumen is freed. Text types out; Enter, Space or a click moves on.

signal finished

const INTRO := [
	"2190.  Port Halo floats above the city the sea swallowed.",
	"When a net snags on the old wrecks, the fleet cuts it loose. A new net costs less than an hour of hauling.",
	"Those nets keep fishing, with no boat and no crew. Nova dives to cut them away, with Pip lighting the dark.",
]
const ENDING := [
	"The Lumen sings. For the first time in a century, the last reef glows.",
	"Nova brings the fleet tags to the surface. Port Halo starts hauling its nets back.",
	"Every net that goes down comes back up. But a century of nets is still down there. Keep diving.",
]

var _lines: Array
var _index := 0
var _label: Label
var _hint: Label
var _typed := 0.0


func setup(lines: Array) -> void:
	_lines = lines


func _ready() -> void:
	size = Vector2(1280, 720)
	var scene := MenuScene.new()
	scene.dim = 0.6
	scene.show_diver = false
	add_child(scene)
	_label = UiKit.label("", 34, false, Art.ICE)
	_label.position = Vector2(180, 250)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size = Vector2(920, 240)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	_hint = UiKit.label("Enter to continue", 16, false, Color(Art.CYAN, 0.8))
	_hint.position = Vector2(0, 640)
	_hint.size = Vector2(1280, 30)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_show_line()


func _show_line() -> void:
	_label.text = _lines[_index]
	_label.visible_ratio = 0.0
	_typed = 0.0


func _process(delta: float) -> void:
	_typed += delta * 45.0
	_label.visible_characters = int(_typed)
	_hint.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 400.0)


func _unhandled_input(event: InputEvent) -> void:
	var advance: bool = event.is_action_pressed("confirm") or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE)
	if not advance:
		return
	if _label.visible_characters < _label.text.length():
		_typed = 9999.0                           # first press finishes the line
		return
	_index += 1
	if _index >= _lines.size():
		finished.emit()
	else:
		_show_line()
