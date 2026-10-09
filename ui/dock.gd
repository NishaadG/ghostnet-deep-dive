class_name Dock
extends Control
# The shop between dives: portraits, records, a grid of upgrade cards and the DIVE button.

signal dive_pressed

const GRID_ORIGIN := Vector2(312, 92)
const GRID_GAP := Vector2(10, 10)

var _cards: Array[UpgradeCard] = []
var _status: Label
var _captain: TextureRect
var _speech: Label
var _mode_button: Button
var _coral_row: HBoxContainer


func _ready() -> void:
	theme = Game.ui_theme
	size = Vector2(1280, 720)            # our parent is a plain Node, so anchors would give size 0
	var background := TextureRect.new()
	background.texture = load("res://assets/sprites/dock_bg.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.size = Vector2(1280, 720)
	background.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(background)
	_build_top_bar()
	_build_portraits()
	_build_cards()
	_build_bottom_row()
	refresh()


func refresh() -> void:
	for card in _cards:
		card.refresh()
	_status.text = "Dive %d        Tags %d        Best %d m" % [Game.dives + 1, Game.tags, Game.best_distance]
	var net_return := Game.level("net_return")
	_captain.texture = load("res://assets/sprites/captain_soft.png" if net_return >= 3 else "res://assets/sprites/captain_stern.png")
	_speech.text = "\"%s\"" % Balance.CAPTAIN_LINES[mini(net_return, Balance.CAPTAIN_LINES.size() - 1)]
	_mode_button.visible = Game.story_complete
	_mode_button.text = "Mode: Endless" if Game.endless_mode else "Mode: Story"
	_update_reef_lights()


# ---- Layout ----

func _build_top_bar() -> void:
	var bar := Panel.new()
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1280, 70)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.08, 0.13, 0.85)
	bar.add_theme_stylebox_override("panel", style)
	add_child(bar)
	_status = _label("", Vector2(24, 14), 26, true, Color.WHITE)
	_label("Reef lights", Vector2(880, 8), 14, false, Color(0.7, 0.9, 1.0))
	_coral_row = HBoxContainer.new()
	_coral_row.position = Vector2(880, 26)
	_coral_row.add_theme_constant_override("separation", 2)
	add_child(_coral_row)


func _build_portraits() -> void:
	var nova := TextureRect.new()
	nova.texture = load("res://assets/sprites/nova_bust.png")
	nova.expand_mode = TextureRect.EXPAND_IGNORE_SIZE     # must come before size, or the texture size wins
	nova.position = Vector2(30, 84)
	nova.size = Vector2(250, 262)
	nova.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(nova)
	_captain = TextureRect.new()
	_captain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_captain.position = Vector2(30, 340)
	_captain.size = Vector2(250, 250)
	_captain.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_captain)
	var bubble := Panel.new()
	bubble.position = Vector2(20, 598)
	bubble.size = Vector2(272, 100)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.1, 0.16, 0.92)
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = Color(1.0, 0.8, 0.3, 0.8)
	bubble.add_theme_stylebox_override("panel", style)
	add_child(bubble)
	_label("Captain Vale", Vector2(32, 602), 13, true, Color(1.0, 0.8, 0.3))
	_speech = _label("", Vector2(32, 622), 15, false, Color.WHITE)
	_speech.size = Vector2(250, 70)
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_cards() -> void:
	for i in Balance.UPGRADE_ORDER.size():
		var card := UpgradeCard.new()
		card.setup(Balance.UPGRADE_ORDER[i])
		card.position = GRID_ORIGIN + Vector2(i % 5, i / 5) * (UpgradeCard.SIZE + GRID_GAP)
		card.bought.connect(refresh)
		add_child(card)
		_cards.append(card)


func _build_bottom_row() -> void:
	_mode_button = Button.new()
	_mode_button.position = Vector2(312, 620)
	_mode_button.size = Vector2(240, 56)
	_mode_button.focus_mode = Control.FOCUS_NONE
	_mode_button.pressed.connect(func():
		Game.endless_mode = not Game.endless_mode
		Game.save_game()
		refresh())
	add_child(_mode_button)
	var dive := Button.new()
	dive.text = "DIVE"
	dive.position = Vector2(930, 612)
	dive.size = Vector2(320, 76)
	dive.focus_mode = Control.FOCUS_NONE
	dive.add_theme_font_override("font", Game.font_bold)
	dive.add_theme_font_size_override("font_size", 44)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		dive.add_theme_color_override(color_name, Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.65, 0.75)
	style.set_corner_radius_all(14)
	dive.add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = Color(0.25, 0.85, 0.95)
	dive.add_theme_stylebox_override("hover", hover)
	dive.pressed.connect(func(): dive_pressed.emit())
	add_child(dive)
	_label("Enter = dive", Vector2(930, 692), 14, false, Color(0.9, 0.95, 1.0))


# One coral per freed animal, up to ten. Lit corals glow.
func _update_reef_lights() -> void:
	for child in _coral_row.get_children():
		child.queue_free()
	var lit := mini(Game.reef_lights(), 10)
	for i in 10:
		var coral := TextureRect.new()
		coral.texture = load("res://assets/sprites/%s_%d.png" % ["coral_lit" if i < lit else "coral_dead", i % 10 if i < lit else i % 4])
		coral.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coral.custom_minimum_size = Vector2(32, 38)
		coral.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_coral_row.add_child(coral)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm"):
		dive_pressed.emit()


func _label(text: String, pos: Vector2, size_px: int, bold: bool, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_override("font", Game.font_bold if bold else Game.font)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label
