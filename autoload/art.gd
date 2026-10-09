extends Node
# The visual identity in one place: palette, a soft glow texture, and small drawing helpers.
# Everything in the game is drawn from code with these, so it all matches.
# (Autoload name: Art.)

const INK := Color("050b1a")          # near-black navy used for outlines and shadows
const CYAN := Color("46f2e8")
const MAGENTA := Color("ff4fa3")
const AMBER := Color("ffb84a")
const VIOLET := Color("9a6bff")
const ICE := Color("d9f4ff")          # near-white blue for highlights and text
const SUIT := Color("1d3157")
const SUIT_LIGHT := Color("34558f")
const NET_COLOR := Color("bfeff5")    # pale teal of a ghost net

var glow_texture: GradientTexture2D
var additive := CanvasItemMaterial.new()


func _ready() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.35, Color(1, 1, 1, 0.45))        # soft shoulder so the glow is not a hard blob
	glow_texture = GradientTexture2D.new()
	glow_texture.gradient = gradient
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(1.0, 0.5)
	glow_texture.width = 128
	glow_texture.height = 128
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


# A soft round glow. Use on a node whose material is Art.additive for a true light-like add.
func glow(ci: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	ci.draw_texture_rect(glow_texture, Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


# A rounded bar between two points (draw_line has square ends, this has round ones).
func capsule(ci: CanvasItem, a: Vector2, b: Vector2, radius: float, color: Color) -> void:
	ci.draw_line(a, b, color, radius * 2.0, true)
	ci.draw_circle(a, radius, color)
	ci.draw_circle(b, radius, color)


# Filled shape with a crisp outline.
func shape(ci: CanvasItem, points: PackedVector2Array, fill: Color, outline: Color, width := 2.0) -> void:
	ci.draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	ci.draw_polyline(closed, outline, width, true)


# Vertical gradient quad: top colour to bottom colour.
func gradient_rect(ci: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	ci.draw_primitive(corners, PackedColorArray([top, top, bottom, bottom]), PackedVector2Array())


# The colours for the water at world x. Zones fade into each other over the last 120 m.
func zone_palette(x_px: float) -> Dictionary:
	var metres := x_px / Balance.PX_PER_M
	var index := Balance.zone_index_at(x_px)
	var zone: Dictionary = Balance.ZONES[index]
	var next: Dictionary = zone
	var blend := 0.0
	if index + 1 < Balance.ZONES.size():
		next = Balance.ZONES[index + 1]
		blend = smoothstep(float(next["start_m"]) - 120.0, float(next["start_m"]), metres)
	var palette := {}
	for key in ["water_top", "water_bottom", "rock", "accent", "tint"]:
		palette[key] = (zone[key] as Color).lerp(next[key], blend)
	palette["dark"] = lerpf(zone["dark"], next["dark"], blend)      # how dark the water is (Trench = nearly black)
	return palette


# Deterministic pseudo-random 0..1 from an integer, so decor looks the same every frame.
func hash01(n: int) -> float:
	var x := (n * 374761393 + 668265263) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	return float(x & 0xffff) / 65535.0


# A one-shot or continuous burst of soft round particles. size is in px; the glow texture is 128 px.
func particles(amount: int, lifetime: float, size_min: float, size_max: float, color: Color, add := true) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = glow_texture
	p.amount = amount
	p.lifetime = lifetime
	p.scale_amount_min = size_min / 128.0
	p.scale_amount_max = size_max / 128.0
	p.color = color
	if add:
		p.material = additive
	p.emitting = false
	return p
