class_name DecorArt
extends RefCounted
# Vector scenery: corals, sea fans, drowned towers, crystals and vents.
# Each function draws one piece at `pos` (the point where it touches the rock) and is
# fully determined by `seed_value`, so it looks identical every frame.

const CORAL_COLORS := [Color("46f2d0"), Color("ff5fa8"), Color("ffb84a"), Color("9a6bff"), Color("5fb8ff")]


# A branching coral. `lit` corals glow in their colour; dead ones are grey-blue and dark.
static func coral(ci: CanvasItem, pos: Vector2, size: float, seed_value: int, variant: int, lit: bool, time: float) -> void:
	var color: Color = CORAL_COLORS[variant % CORAL_COLORS.size()] if lit else Color("46607a")
	var base_width := size * 0.06
	_branch(ci, pos, -PI / 2.0, size, base_width, 3, seed_value, color, lit, time)


static func _branch(ci: CanvasItem, from: Vector2, angle: float, length: float, width: float, depth: int, seed_value: int, color: Color, lit: bool, time: float) -> void:
	var sway := sin(time * 0.8 + seed_value) * 0.04 * (4 - depth)
	var to := from + Vector2(length * 0.55, 0).rotated(angle + sway)
	ci.draw_line(from, to, color.darkened(0.55), width + 2.0, true)
	ci.draw_line(from, to, color, width, true)
	if depth == 0:
		if lit:
			Art.glow(ci, to, width * 5.0 + 10.0, Color(color, 0.5))
			ci.draw_circle(to, width * 1.2, color.lightened(0.5))
		else:
			ci.draw_circle(to, width * 0.9, color)
		return
	var children := 2 + int(Art.hash01(seed_value + depth * 7) * 1.99)
	for i in children:
		var spread := (i - (children - 1) / 2.0) * (0.55 + Art.hash01(seed_value * 3 + i) * 0.3)
		_branch(ci, to, angle + spread, length * 0.62, width * 0.7, depth - 1, seed_value * 5 + i + 1, color, lit, time)


# A swaying fan of glowing stalks.
static func sea_fan(ci: CanvasItem, pos: Vector2, size: float, seed_value: int, color: Color, time: float) -> void:
	var stalks := 7
	for i in stalks:
		var t := i / float(stalks - 1) - 0.5
		var sway := sin(time * 1.1 + i * 0.7 + seed_value) * size * 0.05
		var tip := pos + Vector2(t * size * 0.9 + sway, -size * (0.8 + 0.25 * Art.hash01(seed_value + i)))
		var mid := pos + Vector2(t * size * 0.4 + sway * 0.5, -size * 0.4)
		ci.draw_polyline(PackedVector2Array([pos, mid, tip]), Color(color, 0.7), 2.0, true)
		Art.glow(ci, tip, size * 0.12, Color(color, 0.55))


# A drowned tower: a rooftop at `roof` (top-left), with dim windows and an antenna.
static func tower(ci: CanvasItem, roof: Vector2, width: float, height: float, seed_value: int, body: Color, accent: Color) -> void:
	var rect := Rect2(roof, Vector2(width, height))
	Art.gradient_rect(ci, rect, body.lightened(0.1), body.darkened(0.5))
	ci.draw_line(roof, roof + Vector2(width, 0), Color(accent, 0.8), 3.0, true)
	ci.draw_line(roof, roof + Vector2(0, height), Color(accent, 0.15), 1.5, true)
	ci.draw_line(roof + Vector2(width, 0), roof + Vector2(width, height), Color(accent, 0.15), 1.5, true)
	var columns := maxi(2, int(width / 34.0))
	var rows := int(minf(height, 700.0) / 44.0)
	for row in rows:
		for col in columns:
			var n := seed_value + row * 31 + col * 17
			if Art.hash01(n) > 0.32:
				continue                                             # most windows are dark
			var window_color: Color = [accent, Art.AMBER, Art.CYAN][int(Art.hash01(n + 5) * 2.99)]
			var wp := roof + Vector2(14 + col * (width - 28) / columns, 24 + row * 44)
			ci.draw_rect(Rect2(wp, Vector2(12, 16)), Color(window_color, 0.65))
	# Antenna with a snagged scrap of net hanging off it.
	var mast := roof + Vector2(width * (0.3 + 0.4 * Art.hash01(seed_value)), 0)
	ci.draw_line(mast, mast + Vector2(0, -70), Color(accent, 0.8), 2.0, true)
	ci.draw_circle(mast + Vector2(0, -70), 3.0, accent)


# Rock spikes. `up` true grows from the floor, false hangs from the ceiling.
static func spikes(ci: CanvasItem, pos: Vector2, size: float, seed_value: int, color: Color, glow: Color, up: bool) -> void:
	var direction := -1.0 if up else 1.0
	for i in 3:
		var x := pos.x + (i - 1) * size * 0.28
		var h := size * (0.5 + 0.7 * Art.hash01(seed_value + i))
		var w := size * 0.13
		var tip := Vector2(x + (Art.hash01(seed_value * 7 + i) - 0.5) * size * 0.1, pos.y + direction * h)
		var pts := PackedVector2Array([Vector2(x - w, pos.y), tip, Vector2(x + w, pos.y)])
		Art.shape(ci, pts, color, Color(glow, 0.5), 1.5)
		if Art.hash01(seed_value + i * 3) > 0.5:
			Art.glow(ci, tip, size * 0.1, Color(glow, 0.5))


# A glowing crystal cluster.
static func crystals(ci: CanvasItem, pos: Vector2, size: float, seed_value: int, color: Color, up: bool, time: float) -> void:
	var direction := -1.0 if up else 1.0
	var pulse := 0.65 + 0.35 * sin(time * 2.0 + seed_value)
	for i in 4:
		var lean := (Art.hash01(seed_value + i) - 0.5) * 0.9
		var length := size * (0.45 + 0.6 * Art.hash01(seed_value * 3 + i))
		var base := pos + Vector2((i - 1.5) * size * 0.16, 0)
		var tip := base + Vector2(0, direction * length).rotated(lean)
		var w := size * 0.07
		var pts := PackedVector2Array([base + Vector2(-w, 0), tip, base + Vector2(w, 0)])
		Art.shape(ci, pts, Color(color, 0.45 * pulse + 0.2), color.lightened(0.3), 1.5)
		Art.glow(ci, tip, size * 0.25, Color(color, 0.45 * pulse))


# A hydrothermal vent: a dark chimney with rising glowing plume.
static func vent(ci: CanvasItem, pos: Vector2, size: float, seed_value: int, color: Color, time: float) -> void:
	var w := size * 0.16
	Art.shape(ci, PackedVector2Array([pos + Vector2(-w * 1.6, 0), pos + Vector2(-w, -size * 0.6), pos + Vector2(w, -size * 0.6), pos + Vector2(w * 1.6, 0)]), Color("0a1226"), Color(color, 0.6), 1.5)
	var top := pos + Vector2(0, -size * 0.6)
	for i in 5:
		var t := fmod(time * 0.4 + i * 0.2 + Art.hash01(seed_value) , 1.0)
		var p := top + Vector2(sin(t * 6.0 + i) * 8.0, -t * size * 1.4)
		Art.glow(ci, p, 10.0 + t * 22.0, Color(color, 0.5 * (1.0 - t)))
