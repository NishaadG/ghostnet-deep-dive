class_name UpgradeCard
extends Panel
# One upgrade in the dock: icon, name, level pips, effect, cost and a Buy button.

signal bought

const SIZE := Vector2(182, 250)

var id: String
var _name_label: Label
var _effect_label: Label
var _cost_label: Label
var _button: Button
var _pips: Control
var _tag_icon: TextureRect
var _style := StyleBoxFlat.new()


func setup(upgrade_id: String) -> void:
	id = upgrade_id
	custom_minimum_size = SIZE
	size = SIZE
	var is_net_return := id == "net_return"
	_style.bg_color = Color(0.05, 0.14, 0.2, 0.9)
	_style.set_border_width_all(3 if is_net_return else 1)
	_style.border_color = Color(1.0, 0.8, 0.3) if is_net_return else Color(0.4, 0.7, 0.8, 0.7)
	_style.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", _style)
	var info: Dictionary = Balance.UPGRADE_INFO[id]

	if is_net_return:
		_add_label("PORT HALO PROGRAMME", Vector2(0, 5), 11, true, Color(1.0, 0.8, 0.3)).size.x = SIZE.x
	var icon := TextureRect.new()
	icon.texture = Game.icon(info["icon"])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE     # before size, or the texture size wins
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(51, 24)
	icon.size = Vector2(80, 60)
	add_child(icon)
	_name_label = _add_label(info["name"], Vector2(0, 88), 19, true, Color.WHITE)
	_pips = Control.new()
	_pips.position = Vector2(0, 118)
	_pips.size = Vector2(SIZE.x, 12)
	_pips.draw.connect(_draw_pips)
	add_child(_pips)
	_effect_label = _add_label("", Vector2(8, 134), 13, false, Color(0.8, 0.9, 0.95))
	_effect_label.size = Vector2(SIZE.x - 16, 50)
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_tag_icon = TextureRect.new()
	_tag_icon.texture = load("res://assets/sprites/tag.png")
	_tag_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tag_icon.position = Vector2(46, 200)
	_tag_icon.size = Vector2(30, 20)
	add_child(_tag_icon)
	_cost_label = _add_label("", Vector2(82, 195), 18, true, Color(1.0, 0.85, 0.3))
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_button = Button.new()
	_button.text = "Buy"
	_button.position = Vector2(16, 222)
	_button.size = Vector2(SIZE.x - 32, 24)
	_button.add_theme_font_size_override("font_size", 14)
	_button.focus_mode = Control.FOCUS_NONE      # so Enter always means DIVE
	_button.pressed.connect(_on_buy)
	add_child(_button)
	refresh()


func refresh() -> void:
	var level := Game.level(id)
	var maxed := level >= Balance.upgrade_max(id) and not Game.story_complete
	var text: String = Balance.UPGRADE_INFO[id]["effect"]
	if id == "net_return":
		text += "\nNow x%.2f" % Balance.net_factor(level)
	_effect_label.text = text
	_cost_label.text = "MAX" if maxed else str(Balance.upgrade_cost(id, level))
	_tag_icon.visible = not maxed
	if maxed:
		_cost_label.position.x = 0
		_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cost_label.size.x = SIZE.x
	else:
		_cost_label.position.x = 82
		_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_button.disabled = not Game.can_buy(id)
	_button.text = "Maxed" if maxed else "Buy"
	_pips.queue_redraw()


func _on_buy() -> void:
	if Game.buy(id):
		bought.emit()


# Filled dots for owned levels, empty for the rest. Past the cap (Endless) we show "Lv N".
func _draw_pips() -> void:
	var level := Game.level(id)
	var total := Balance.upgrade_max(id)
	if level > total:
		_pips.draw_string(Game.font_bold, Vector2(0, 11), "Level %d" % level, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 14, Color(1.0, 0.85, 0.3))
		return
	var spacing := 18.0
	var start_x := (SIZE.x - spacing * (total - 1)) / 2.0
	for i in total:
		var centre := Vector2(start_x + i * spacing, 6)
		if i < level:
			_pips.draw_circle(centre, 6.0, Color(0.4, 0.95, 1.0))
		else:
			_pips.draw_arc(centre, 5.0, 0.0, TAU, 16, Color(0.6, 0.8, 0.9, 0.7), 2.0)


func _add_label(text: String, pos: Vector2, size_px: int, bold: bool, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size.x = SIZE.x
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", Game.font_bold if bold else Game.font)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label
