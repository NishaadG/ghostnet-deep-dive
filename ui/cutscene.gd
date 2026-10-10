class_name Cutscene
extends Control
# Plays one scene from Story.SCENES: the stage picture plus comic-style text on top.
# Narration appears in a yellow caption box (like the comic), dialogue in a speech box with the
# speaker's name. Text types out; Enter, Space, a click or a tap finishes the line, then moves on.
# Esc or the SKIP button ends the scene at once. Used between screens and, paused, inside a dive.

signal finished

const TYPE_SPEED := 50.0          # characters per second
const FADE_TIME := 0.35           # black fade when the set changes
const BAR := 48.0                 # height of the cinema letterbox bars

var scene_id := ""
var stage: CutsceneStage
var _beats: Array = []
var _index := -1
var _typed := 0.0
var _auto_wait := -1.0            # seconds left before a text-less beat moves on by itself
var _done := false
var _age := 0.0

var _caption_panel: Panel
var _caption: Label
var _speech_panel: Panel
var _name_chip: Panel
var _name: Label
var _speech: Label
var _hint: Label
var _title: Label
var _fade: ColorRect
var _active: Label               # whichever text label is typing right now


func setup(id: String) -> void:
	scene_id = id
	_beats = Story.beats_of(id)


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP           # clicks here never reach the dive below
	var back := ColorRect.new()
	back.color = Art.INK
	back.size = size
	add_child(back)
	stage = CutsceneStage.new()
	add_child(stage)
	_build_bars()
	_build_caption()
	_build_speech()
	_title = UiKit.label(Story.title_of(scene_id).to_upper(), 18, true, Art.AMBER)
	_title.position = Vector2(0, 12)
	_title.size = Vector2(1280, 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	var skip := UiKit.button("SKIP  >>", Vector2(130, 36), Art.CYAN, false, 15)
	skip.position = Vector2(1130, 6)
	skip.pressed.connect(_finish)
	add_child(skip)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.size = size
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_next()


func _build_bars() -> void:
	var bars := Control.new()
	bars.size = size
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.draw.connect(func():
		bars.draw_rect(Rect2(0, 0, 1280, BAR), Color.BLACK)
		bars.draw_rect(Rect2(0, 720 - BAR, 1280, BAR), Color.BLACK))
	add_child(bars)


# Narration: dark bold text on an amber box, top left, like the yellow captions in the comic.
func _build_caption() -> void:
	_caption_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ffd23f")
	style.border_color = Art.INK
	style.set_border_width_all(3)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 0
	style.shadow_offset = Vector2(6, 6)
	style.set_corner_radius_all(4)
	_caption_panel.add_theme_stylebox_override("panel", style)
	_caption_panel.position = Vector2(60, 72)
	add_child(_caption_panel)
	_caption = UiKit.label("", 25, true, Art.INK)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART      # before size, or it will not wrap
	_caption.position = Vector2(20, 12)
	_caption.size = Vector2(640, 40)
	_caption_panel.add_child(_caption)


# Dialogue: a glass box along the bottom, with the speaker's name on a coloured chip.
func _build_speech() -> void:
	_speech_panel = UiKit.panel(Vector2(140, 532), Vector2(1000, 132), Art.CYAN, 0.85)
	add_child(_speech_panel)
	_speech = UiKit.label("", 26, false, Art.ICE)
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.position = Vector2(28, 26)
	_speech.size = Vector2(944, 96)
	_speech_panel.add_child(_speech)
	_name_chip = Panel.new()
	_name_chip.position = Vector2(164, 514)
	add_child(_name_chip)
	_name = UiKit.label("", 16, true, Art.INK)
	_name.position = Vector2(14, 4)
	_name_chip.add_child(_name)
	_hint = UiKit.label(">", 26, true, Art.CYAN)
	add_child(_hint)


func _process(delta: float) -> void:
	_age += delta
	_title.modulate.a = clampf(3.5 - _age, 0.0, 1.0)              # the scene's name fades after a few seconds
	if _active:
		_typed += delta * TYPE_SPEED
		_active.visible_characters = int(_typed)
		var typing := _active.visible_characters < _active.text.length()
		_hint.visible = not typing
		_hint.modulate.a = 0.5 + 0.5 * sin(_age * 6.0)
	if _auto_wait > 0.0:
		_auto_wait -= delta
		if _auto_wait <= 0.0:
			_next()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("pause"):
		_finish()
		accept_event()
		return
	# A tap on a phone arrives as a left click too (Godot emulates the mouse from touch).
	var tap: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event.is_action_pressed("confirm") or tap or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		advance()
		accept_event()


# One press: finish typing the current line, or move on to the next beat.
func advance() -> void:
	if _active and _active.visible_characters < _active.text.length():
		_typed = 9999.0
		return
	if _auto_wait > 0.0:
		return                                      # an action beat finishes by itself
	_next()


func _next() -> void:
	_auto_wait = -1.0
	_index += 1
	if _index >= _beats.size():
		_finish()
		return
	var beat: Dictionary = _beats[_index]
	if beat.has("set"):
		stage.show_set(String(beat["set"]))
		_fade.color.a = 1.0
		create_tween().tween_property(_fade, "color:a", 0.0, FADE_TIME)
	if beat.has("cam"):
		var cam: Array = beat["cam"]
		stage.camera_to(Vector2(float(cam[0]), float(cam[1])), float(cam[2]), float(beat.get("t", 1.2)))
	var actions: Variant = beat.get("act", [])
	for action in (actions if actions is Array else [actions]):
		stage.act(String(action))
	if beat.has("sfx"):
		Audio.play(String(beat["sfx"]), -2.0)
	_show_text(beat)


func _show_text(beat: Dictionary) -> void:
	_caption_panel.visible = beat.has("cap")
	var speaking := beat.has("say")
	_speech_panel.visible = speaking
	_name_chip.visible = speaking
	_hint.visible = false
	_active = null
	stage.set_speaker(String(beat.get("who", "")) if speaking else "")
	if beat.has("cap"):
		_caption.text = String(beat["cap"])
		var text_size := Game.font_bold.get_multiline_string_size(_caption.text, HORIZONTAL_ALIGNMENT_LEFT, 640, 25)
		_caption_panel.size = Vector2(minf(text_size.x, 640.0) + 44, text_size.y + 26)
		_caption.size = Vector2(640, text_size.y + 4)
		_hint.position = _caption_panel.position + _caption_panel.size + Vector2(-26, -36)
		_hint.add_theme_color_override("font_color", Art.INK)
		_active = _caption
	elif speaking:
		var who: Dictionary = Story.SPEAKERS.get(String(beat.get("who", "")), {"name": "", "color": Art.CYAN})
		var color: Color = who["color"]
		_speech_panel.add_theme_stylebox_override("panel", UiKit.glass(color, 0.88))
		var chip := StyleBoxFlat.new()
		chip.bg_color = color
		chip.set_corner_radius_all(6)
		_name_chip.add_theme_stylebox_override("panel", chip)
		_name.text = String(who["name"])
		_name_chip.size = Vector2(Game.font_bold.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28, 30)
		_speech.text = String(beat["say"])
		_hint.position = Vector2(1106, 620)
		_hint.add_theme_color_override("font_color", color)
		_active = _speech
	else:
		_auto_wait = float(beat.get("wait", 1.0))
	if _active:
		_typed = 0.0
		_active.visible_characters = 0


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
