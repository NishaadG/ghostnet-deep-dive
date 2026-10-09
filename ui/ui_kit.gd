class_name UiKit
extends RefCounted
# Shared look for every menu: glass panels with a thin neon outline, rounded buttons, text helpers.

static func glass(accent := Art.CYAN, alpha := 0.62, radius := 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Art.INK.r, Art.INK.g + 0.03, Art.INK.b + 0.08, alpha)
	style.border_color = Color(accent, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(accent, 0.12)
	style.shadow_size = 8
	return style


static func button_style(fill: Color, border: Color, radius := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	return style


# A neon button. `accent` picks the glow colour; `primary` fills it solid for the main action.
static func button(text: String, size: Vector2, accent := Art.CYAN, primary := false, font_size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.size = size
	b.focus_mode = Control.FOCUS_NONE                  # keeps Enter free for the confirm action
	b.add_theme_font_override("font", Game.font_bold)
	b.add_theme_font_size_override("font_size", font_size)
	var fill := Color(accent, 0.85) if primary else Color(accent, 0.10)
	var hover := Color(accent.lightened(0.2), 1.0) if primary else Color(accent, 0.25)
	var text_color := Art.INK if primary else Art.ICE
	b.add_theme_stylebox_override("normal", button_style(fill, accent))
	b.add_theme_stylebox_override("hover", button_style(hover, accent.lightened(0.4)))
	b.add_theme_stylebox_override("pressed", button_style(accent.darkened(0.2), Color.WHITE))
	b.add_theme_stylebox_override("disabled", button_style(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.15)))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(color_name, text_color)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.pressed.connect(func(): Audio.play("click", -4.0))
	return b


static func label(text: String, size_px: int, bold := false, color := Art.ICE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Game.font_bold if bold else Game.font)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l


static func panel(pos: Vector2, size: Vector2, accent := Art.CYAN, alpha := 0.62) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.add_theme_stylebox_override("panel", glass(accent, alpha))
	return p
