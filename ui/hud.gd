class_name Hud
extends Control
# In-run readout, drawn by hand: oxygen and fuel bars, numbers, tags, and a strip showing the next wall.

var run: Run
var _tag_icon: Texture2D = load("res://assets/sprites/tag.png")


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if run == null:
		return
	var player := run.player
	var oxygen_fraction: float = player.oxygen / run.stats["max_oxygen"]
	var low: bool = oxygen_fraction < 0.35
	var critical: bool = oxygen_fraction < 0.15
	var o2_color := Color(0.3, 0.85, 1.0)
	if critical:
		o2_color = Color(1.0, 0.25, 0.25).lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0))
	elif low:
		o2_color = Color(1.0, 0.65, 0.2)
	_bar(Vector2(24, 24), Vector2(320, 24), oxygen_fraction, o2_color, "O2  %.1f s" % player.oxygen)
	_bar(Vector2(24, 58), Vector2(320, 16), player.fuel / run.stats["max_fuel"], Color(1.0, 0.8, 0.3), "FUEL")

	var metres := maxf(0.0, player.position.x / Balance.PX_PER_M)
	_text("%d m" % metres, Vector2(1256, 48), 34, HORIZONTAL_ALIGNMENT_RIGHT, Game.font_bold)
	_text("depth %d m   %d px/s" % [maxf(0.0, player.position.y / Balance.PX_PER_M), player.vel.length()],
			Vector2(1256, 76), 18, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_texture_rect(_tag_icon, Rect2(560, 20, 42, 28), false)
	_text("%d" % run.tags_so_far(), Vector2(612, 46), 26, HORIZONTAL_ALIGNMENT_LEFT, Game.font_bold)
	_next_wall_strip(metres)


func _bar(pos: Vector2, size_px: Vector2, fraction: float, color: Color, label: String) -> void:
	draw_rect(Rect2(pos, size_px), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(pos, Vector2(size_px.x * clampf(fraction, 0.0, 1.0), size_px.y)), color)
	draw_rect(Rect2(pos, size_px), Color(1, 1, 1, 0.5), false, 2.0)
	_text(label, pos + Vector2(8, size_px.y - 5), int(size_px.y * 0.7), HORIZONTAL_ALIGNMENT_LEFT, Game.font, Color(0, 0, 0, 0.8))


# Thin strip along the bottom: how far to the next net wall. Hidden once all walls are behind us.
func _next_wall_strip(metres: float) -> void:
	var previous := 0.0
	for wall_m in Balance.WALL_DISTANCES_M:
		if metres < wall_m:
			var fraction: float = (metres - previous) / (wall_m - previous)
			var strip := Rect2(340, 700, 600, 6)
			draw_rect(strip, Color(0, 0, 0, 0.5))
			draw_rect(Rect2(strip.position, Vector2(strip.size.x * fraction, strip.size.y)), Color(0.9, 0.9, 1.0, 0.8))
			_text("next net wall  %d m" % wall_m, Vector2(640, 694), 14, HORIZONTAL_ALIGNMENT_CENTER)
			return
		previous = wall_m


func _text(text: String, pos: Vector2, size_px: int, align: HorizontalAlignment, font: Font = Game.font, color := Color.WHITE) -> void:
	# draw_string anchors the baseline; for right/centre alignment we give it a box around pos.
	var width := 400.0
	var origin := pos
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		origin.x -= width
	elif align == HORIZONTAL_ALIGNMENT_CENTER:
		origin.x -= width / 2.0
	draw_string(font, origin + Vector2(1, 1), text, align, width, size_px, Color(0, 0, 0, 0.6))
	draw_string(font, origin, text, align, width, size_px, color)
