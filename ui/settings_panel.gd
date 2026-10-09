class_name SettingsPanel
extends Control
# Volume sliders and a few switches. Changes apply and save immediately.

signal closed

var _toggle_buttons := {}


func _ready() -> void:
	size = Vector2(1280, 720)
	var shade := ColorRect.new()
	shade.color = Color(Art.INK, 0.82)
	shade.size = size
	add_child(shade)
	add_child(UiKit.panel(Vector2(340, 80), Vector2(600, 560)))
	var title := UiKit.label("SETTINGS", 38, true)
	title.position = Vector2(380, 98)
	add_child(title)
	var y := 170.0
	for entry in [["Master volume", "master"], ["Music", "music"], ["Sound effects", "sfx"]]:
		_add_slider(entry[0], entry[1], y)
		y += 60.0
	y += 8.0
	for entry in [["Fullscreen", "fullscreen"], ["Screen shake", "shake"], ["Touch controls", "touch"]]:
		_add_toggle(entry[0], entry[1], y)
		y += 56.0
	var help := UiKit.label("Controls:  A / D or Left / Right = tilt      Space = boost      Esc = pause\nTouch: hold the top half of the screen to tilt up, the bottom half to tilt down.", 14, false, Color(Art.ICE, 0.75))
	help.position = Vector2(380, 530)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.size = Vector2(520, 60)
	add_child(help)
	var close := UiKit.button("DONE", Vector2(200, 48), Art.CYAN, true)
	close.position = Vector2(540, 584)
	close.pressed.connect(func(): closed.emit())
	add_child(close)


func _add_slider(title: String, key: String, y: float) -> void:
	var label := UiKit.label(title, 20)
	label.position = Vector2(380, y)
	add_child(label)
	var slider := NeonSlider.new()
	slider.position = Vector2(600, y + 4)
	slider.size = Vector2(300, 30)
	slider.value = float(Game.settings[key])
	slider.changed.connect(func(value: float):
		Game.settings[key] = value
		Audio.apply_volumes()
		Game.save_settings())
	add_child(slider)


func _add_toggle(title: String, key: String, y: float) -> void:
	var label := UiKit.label(title, 20)
	label.position = Vector2(380, y)
	add_child(label)
	var button := UiKit.button("", Vector2(150, 40), Art.CYAN, false, 18)
	button.position = Vector2(750, y - 4)
	button.pressed.connect(func():
		Game.settings[key] = not bool(Game.settings[key])
		Game.apply_settings()
		Game.save_settings()
		_refresh_toggles())
	add_child(button)
	_toggle_buttons[key] = button
	_refresh_toggles()


func _refresh_toggles() -> void:
	for key in _toggle_buttons:
		(_toggle_buttons[key] as Button).text = "ON" if bool(Game.settings[key]) else "OFF"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		closed.emit()
		get_viewport().set_input_as_handled()
