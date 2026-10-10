class_name Title
extends Control
# The first screen: animated reef, neon logo and the main menu.
# PLAY opens the save-slot screen; CONTINUE jumps straight into the last slot used.

signal play_pressed
signal continue_pressed(slot: int)
signal settings_pressed
signal story_pressed
signal quit_pressed

var _logo: Control
var _credits: Control
var _time := 0.0


func _ready() -> void:
	size = Vector2(1280, 720)
	var scene := MenuScene.new()
	scene.dim = 0.15
	add_child(scene)
	_logo = Control.new()
	_logo.size = size
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.draw.connect(_draw_logo)
	add_child(_logo)
	_build_buttons()
	if Debug.ENABLED:                                 # DEBUG mode or the REAL game (see autoload/debug.gd)
		var mode := UiKit.button("", Vector2(230, 42), Art.MAGENTA, false, 15)
		mode.position = Vector2(20, 24)
		var show_mode := func(): mode.text = "MODE:  DEBUG" if Debug.active else "MODE:  REAL GAME"
		show_mode.call()
		mode.pressed.connect(func():
			Debug.set_active(not Debug.active)
			show_mode.call())
		add_child(mode)
	var fullscreen := UiKit.button("FULLSCREEN", Vector2(170, 42), Art.CYAN, false, 15)
	fullscreen.position = Vector2(1090, 24)
	fullscreen.pressed.connect(func():
		Game.settings["fullscreen"] = not bool(Game.settings["fullscreen"])
		Game.apply_settings()
		Game.save_settings())
	add_child(fullscreen)
	var footer := UiKit.label("Cleanup helps one animal at a time. The problem only ends at its source.   |   SDG 14: Life Below Water", 15, false, Color(Art.ICE, 0.7))
	footer.position = Vector2(0, 690)
	footer.size = Vector2(1280, 24)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(footer)


func _build_buttons() -> void:
	var names: Array[String] = []
	var actions: Array[Callable] = []
	var last := int(Game.settings.get("last_slot", 0))
	if last > 0 and not Game.slot_summary(last).is_empty():
		names.append("CONTINUE   slot %d" % last)
		actions.append(func(): continue_pressed.emit(last))
	names.append_array(["PLAY", "STORY", "SETTINGS", "CREDITS"])
	actions.append_array([func(): play_pressed.emit(), func(): story_pressed.emit(), func(): settings_pressed.emit(), _show_credits])
	if not OS.has_feature("web"):
		names.append("QUIT")
		actions.append(func(): quit_pressed.emit())
	for i in names.size():
		var primary := i == 0
		var button := UiKit.button(names[i], Vector2(340, 50), Art.CYAN if i < names.size() - 1 else Art.MAGENTA, primary, 22)
		button.position = Vector2(470, 318 + i * 58)
		button.pressed.connect(actions[i])
		add_child(button)


func _process(delta: float) -> void:
	_time += delta
	_logo.queue_redraw()


# Neon logo: a magenta and a cyan copy slightly offset behind a bright white one.
func _draw_logo() -> void:
	var title := "GHOSTNET"
	var size_px := 132
	var width := Game.font_bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var origin := Vector2(640.0 - width / 2.0, 228.0 + sin(_time * 0.8) * 4.0)
	Art.glow(_logo, Vector2(640, 190), 420.0, Color(Art.CYAN, 0.12))
	_logo.draw_string(Game.font_bold, origin + Vector2(-4, 3), title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(Art.MAGENTA, 0.75))
	_logo.draw_string(Game.font_bold, origin + Vector2(4, -3), title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(Art.CYAN, 0.8))
	_logo.draw_string(Game.font_bold, origin, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0.96, 0.99, 1.0))
	var subtitle := "D E E P   D I V E"
	var sub_width := Game.font_bold.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	_logo.draw_string(Game.font_bold, Vector2(640.0 - sub_width / 2.0, 282.0), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(Art.AMBER, 0.95))
	_logo.draw_line(Vector2(520, 296), Vector2(760, 296), Color(Art.AMBER, 0.6), 2.0, true)


func _show_credits() -> void:
	if _credits:
		_credits.queue_free()
	_credits = Control.new()
	_credits.size = size
	add_child(_credits)
	var shade := ColorRect.new()
	shade.color = Color(Art.INK, 0.93)
	shade.size = size
	_credits.add_child(shade)
	_credits.add_child(UiKit.panel(Vector2(230, 40), Vector2(820, 640)))
	var heading := UiKit.label("CREDITS", 34, true)
	heading.position = Vector2(270, 56)
	_credits.add_child(heading)
	# One column of paragraphs that wrap inside the panel, so nothing can run past its edge.
	var column := VBoxContainer.new()
	column.position = Vector2(270, 112)
	column.custom_minimum_size = Vector2(740, 0)
	column.add_theme_constant_override("separation", 10)
	_credits.add_child(column)
	var lines := [
		["GHOSTNET: Deep Dive is a game about ghost nets: fishing nets lost or cut loose that keep trapping sea life.", Art.ICE],
		["Message: cleanup helps one animal at a time, but the problem only ends at its source (SDG 14, Life Below Water).", Art.CYAN],
		["Art: every shape, glow and animation is drawn by code, original to this project.", Art.ICE],
		["Music: two original tracks synthesised by tools/make_music.py. Sound effects: original kit audio.", Art.ICE],
		["Font: Poppins, SIL Open Font License.   Engine: Godot 4.6, GDScript only, no add-ons.", Art.ICE],
		["AI tool disclosure: this game's scripts, art code, docs and tests were written with an AI coding assistant (Claude Code).", Art.AMBER],
	]
	for entry in lines:
		var label := UiKit.label(entry[0], 17, false, entry[1])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(740, 0)
		column.add_child(label)
	var back := UiKit.button("BACK", Vector2(200, 50), Art.CYAN, true)
	back.position = Vector2(540, 604)
	back.pressed.connect(func(): _credits.queue_free())
	_credits.add_child(back)
