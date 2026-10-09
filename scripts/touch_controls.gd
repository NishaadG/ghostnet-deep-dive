class_name TouchControls
extends Control
# On-screen controls for phones and tablets: hold the top half of the screen to tilt up,
# the bottom half to tilt down, and the BOOST button for thrust. They press the same input
# actions the keyboard does, so the player code does not know the difference.

const BOOST_CENTRE := Vector2(1150, 580)
const BOOST_RADIUS := 70.0

var _holds := {}          # touch index -> "tilt_up" / "tilt_down" / "thrust"


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_touch(event.index, event.position, true)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and Game.settings["touch"]:
		_touch(-1, get_global_mouse_position(), event.pressed)


func _touch(index: int, screen_pos: Vector2, pressed: bool) -> void:
	var position := screen_pos
	var action := ""
	if pressed:
		if position.distance_to(BOOST_CENTRE) < BOOST_RADIUS:
			action = "thrust"
		else:
			action = "tilt_up" if position.y < 360.0 else "tilt_down"
	if _holds.get(index, "") != action:
		_release(index)
		if action != "":
			_holds[index] = action
			Input.action_press(action)
	queue_redraw()


func _release(index: int) -> void:
	if _holds.has(index):
		Input.action_release(_holds[index])
		_holds.erase(index)


func _draw() -> void:
	var up_on := "tilt_up" in _holds.values()
	var down_on := "tilt_down" in _holds.values()
	draw_rect(Rect2(0, 130, 1280, 230), Color(Art.CYAN, 0.10 if up_on else 0.03))
	draw_rect(Rect2(0, 360, 1280, 230), Color(Art.CYAN, 0.10 if down_on else 0.03))
	draw_string(Game.font, Vector2(0, 250), "TILT UP", HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, Color(Art.ICE, 0.25))
	draw_string(Game.font, Vector2(0, 500), "TILT DOWN", HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, Color(Art.ICE, 0.25))
	var boost_on := "thrust" in _holds.values()
	Art.glow(self, BOOST_CENTRE, 120.0, Color(Art.AMBER, 0.3 if boost_on else 0.1))
	draw_circle(BOOST_CENTRE, BOOST_RADIUS, Color(Art.AMBER, 0.35 if boost_on else 0.15))
	draw_arc(BOOST_CENTRE, BOOST_RADIUS, 0.0, TAU, 32, Color(Art.AMBER, 0.8), 3.0, true)
	draw_string(Game.font_bold, BOOST_CENTRE + Vector2(-60, 8), "BOOST", HORIZONTAL_ALIGNMENT_CENTER, 120, 22, Art.ICE)
