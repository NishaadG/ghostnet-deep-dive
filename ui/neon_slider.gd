class_name NeonSlider
extends Control
# A drag-or-click slider (0..1) in the game's neon style. Emits `changed` with the new value.

signal changed(value: float)

var value := 0.5
var accent := Art.CYAN
var _dragging := false


func _init() -> void:
	custom_minimum_size = Vector2(260, 30)
	size = Vector2(260, 30)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_set_from_x(event.position.x)
	elif event is InputEventMouseMotion and _dragging:
		_set_from_x(event.position.x)


func _set_from_x(x: float) -> void:
	value = clampf(x / size.x, 0.0, 1.0)
	changed.emit(value)
	queue_redraw()


func _draw() -> void:
	var y := size.y / 2.0
	draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.15), 6.0, true)
	draw_line(Vector2(0, y), Vector2(size.x * value, y), accent, 6.0, true)
	Art.glow(self, Vector2(size.x * value, y), 26.0, Color(accent, 0.45))
	draw_circle(Vector2(size.x * value, y), 11.0, Art.INK)
	draw_circle(Vector2(size.x * value, y), 8.0, accent.lightened(0.3))
