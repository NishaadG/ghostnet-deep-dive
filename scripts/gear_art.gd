class_name GearArt
extends RefCounted
# Vector drawings of every gear tier. The same functions draw the gear on the diver in a dive
# and the small icons in the workshop, so what you buy is exactly what you see.
# All shapes are in the diver's local space: x forward (right), y down, origin at the torso.

const METAL := Color("2a3f66")
const METAL_LIGHT := Color("4a6aa0")


# ---- Craft: the board or wing Nova rides on (tiers 0..5) ----
static func draw_craft(ci: CanvasItem, tier: int, time: float) -> void:
	match tier:
		0:   # Kickboard: a plain foam plank
			Art.shape(ci, _rect_poly(-14, 12, 34, 5), Color("d9c9a3"), Art.INK)
		1:   # Skim Sled: pointed wedge
			Art.shape(ci, PackedVector2Array([Vector2(-30, 12), Vector2(26, 12), Vector2(44, 17), Vector2(-24, 19)]), METAL_LIGHT, Art.INK)
			ci.draw_line(Vector2(-22, 15), Vector2(34, 15), Art.CYAN, 2.0, true)
		2:   # Hydrofoil: sled on two struts with small foils
			Art.shape(ci, PackedVector2Array([Vector2(-32, 12), Vector2(30, 12), Vector2(48, 16), Vector2(-26, 19)]), METAL_LIGHT, Art.INK)
			for x in [-14.0, 22.0]:
				ci.draw_line(Vector2(x, 19), Vector2(x, 28), Art.INK, 3.0, true)
				Art.shape(ci, PackedVector2Array([Vector2(x - 12, 28), Vector2(x + 12, 28), Vector2(x + 4, 31), Vector2(x - 8, 31)]), Art.CYAN.darkened(0.2), Art.INK)
		3:   # Manta Wing: swept wing with a glowing leading edge
			_wing(ci, 1.0, Art.CYAN, time)
		4:   # Ray Frame: bigger wing with ribs and a tail
			_wing(ci, 1.3, Art.MAGENTA, time)
			ci.draw_line(Vector2(-34, 24), Vector2(-78, 34), Art.INK, 4.0, true)
		5:   # Leviathan: huge wing with glowing veins
			_wing(ci, 1.65, Art.AMBER, time)
			ci.draw_line(Vector2(-40, 25), Vector2(-96, 36), Art.INK, 4.0, true)


static func _wing(ci: CanvasItem, s: float, glow: Color, time: float) -> void:
	var pts := PackedVector2Array([Vector2(40, 12), Vector2(-4, 30) * s, Vector2(-46, 56) * s, Vector2(-30, 26) * s, Vector2(-58, 22) * s, Vector2(-24, 14)])
	pts[1] = Vector2(-4 * s, 14 + 16 * s)
	pts[2] = Vector2(-46 * s, 14 + 40 * s)
	pts[3] = Vector2(-30 * s, 14 + 14 * s)
	pts[4] = Vector2(-60 * s, 12 + 8 * s)
	Art.shape(ci, pts, Color("22407a"), Art.INK)
	ci.draw_colored_polygon(pts, Color(glow, 0.22))
	var edge := PackedVector2Array([pts[0], pts[1], pts[2]])
	ci.draw_polyline(edge, glow, 3.0, true)
	var pulse := 0.5 + 0.5 * sin(time * 3.0)
	for i in 3:
		var from := Vector2(20 - i * 14, 14)
		var to: Vector2 = pts[2].lerp(pts[3], i / 2.0)
		ci.draw_line(from, to, Color(glow, 0.35 + 0.3 * pulse), 1.5, true)


# ---- Booster: pump or jet on the back (tiers 0..5). `thrust` 0..1 draws the flame. ----
static func draw_booster(ci: CanvasItem, tier: int, thrust: float, time: float) -> void:
	var mount := Vector2(-30, -3)
	match tier:
		0:   # Flipper Pump: a small hand pump, no flame, just bubbles
			Art.shape(ci, _rect_poly(mount.x - 8, mount.y - 3, 10, 6), METAL, Art.INK)
		1:   # Mini Jet
			Art.shape(ci, _rect_poly(mount.x - 14, mount.y - 4, 18, 8), METAL_LIGHT, Art.INK)
		2:   # Twin Jet
			for dy in [-6.0, 4.0]:
				Art.shape(ci, _rect_poly(mount.x - 16, mount.y + dy - 3, 20, 6), METAL_LIGHT, Art.INK)
		3:   # Impeller: a shroud ring
			Art.shape(ci, _rect_poly(mount.x - 14, mount.y - 8, 18, 16), METAL, Art.INK)
			ci.draw_arc(Vector2(mount.x - 14, mount.y), 8.0, -PI / 2, PI / 2, 12, Art.CYAN, 2.0, true)
		4:   # Plasma Drive: vents with a live core
			Art.shape(ci, _rect_poly(mount.x - 20, mount.y - 8, 24, 16), METAL, Art.INK)
			Art.glow(ci, Vector2(mount.x - 8, mount.y), 12.0, Color(Art.CYAN, 0.5 + 0.3 * sin(time * 6.0)))
		5:   # Torpedo Drive: a long pod
			Art.shape(ci, PackedVector2Array([Vector2(mount.x + 6, mount.y - 7), Vector2(mount.x - 30, mount.y - 9), Vector2(mount.x - 36, mount.y), Vector2(mount.x - 30, mount.y + 9), Vector2(mount.x + 6, mount.y + 7)]), METAL_LIGHT, Art.INK)
			Art.glow(ci, Vector2(mount.x - 22, mount.y), 14.0, Color(Art.VIOLET, 0.6))
	if thrust > 0.0 and tier > 0:
		_flame(ci, Vector2(mount.x - 14 - tier * 3.0, mount.y), tier, thrust, time)


static func _flame(ci: CanvasItem, origin: Vector2, tier: int, thrust: float, time: float) -> void:
	var core := Color.WHITE
	var outer := Art.AMBER
	if tier >= 5:
		outer = Art.VIOLET
	elif tier >= 3:
		outer = Art.CYAN
	var length := (22.0 + tier * 7.0) * (0.85 + 0.15 * sin(time * 40.0)) * thrust
	var half := 3.0 + tier * 0.9
	Art.glow(ci, origin + Vector2(-length * 0.4, 0), length * 0.9, Color(outer, 0.45))
	ci.draw_colored_polygon(PackedVector2Array([origin + Vector2(0, -half), origin + Vector2(-length, 0), origin + Vector2(0, half)]), outer)
	ci.draw_colored_polygon(PackedVector2Array([origin + Vector2(0, -half * 0.5), origin + Vector2(-length * 0.6, 0), origin + Vector2(0, half * 0.5)]), core)


# ---- Cutter: the tool in Nova's hand (tiers 0..5), drawn at the hand position ----
static func draw_cutter(ci: CanvasItem, tier: int, hand: Vector2, time: float) -> void:
	match tier:
		0:   # Wire Snips
			ci.draw_line(hand, hand + Vector2(10, -4), Art.ICE, 2.5, true)
			ci.draw_line(hand, hand + Vector2(10, 4), Art.ICE, 2.5, true)
		1:   # Shears
			ci.draw_line(hand, hand + Vector2(16, -5), Art.ICE, 3.0, true)
			ci.draw_line(hand, hand + Vector2(16, 5), Art.ICE, 3.0, true)
		2:   # Arc Cutter: short blade with a spark tip
			ci.draw_line(hand, hand + Vector2(18, 0), METAL_LIGHT, 4.0, true)
			Art.glow(ci, hand + Vector2(20, 0), 10.0, Color(Art.CYAN, 0.8))
		3:   # Plasma Blade
			ci.draw_line(hand, hand + Vector2(28, 0), Color(Art.CYAN, 0.9), 4.0, true)
			ci.draw_line(hand, hand + Vector2(28, 0), Color.WHITE, 1.5, true)
			Art.glow(ci, hand + Vector2(16, 0), 16.0, Color(Art.CYAN, 0.45))
		4:   # Net Shredder: a spinning serrated disc
			_disc(ci, hand + Vector2(12, 0), 12.0, 8, time * 12.0, Art.MAGENTA)
		5:   # Reef Saw: a big disc with a glow
			Art.glow(ci, hand + Vector2(14, 0), 26.0, Color(Art.AMBER, 0.4))
			_disc(ci, hand + Vector2(14, 0), 17.0, 12, time * 16.0, Art.AMBER)


static func _disc(ci: CanvasItem, centre: Vector2, radius: float, teeth: int, spin: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in teeth * 2:
		var r := radius if i % 2 == 0 else radius * 0.72
		pts.append(centre + Vector2(r, 0).rotated(spin + TAU * i / (teeth * 2.0)))
	Art.shape(ci, pts, color.darkened(0.45), color, 1.5)
	ci.draw_circle(centre, radius * 0.25, Art.INK)


# ---- Icons for the workshop ----
# Draws a gear tier centred at `centre`. Each slot has its own framing so every tier fills the icon.
static func draw_icon(ci: CanvasItem, id: String, tier: int, centre: Vector2, size: float, time: float) -> void:
	var offset := Vector2.ZERO          # the middle of the artwork in its own coordinates
	var unit := 80.0                    # artwork width that should fill `size`
	match id:
		"craft":
			offset = Vector2(-8, 30)
			unit = [60.0, 70.0, 80.0, 100.0, 125.0, 150.0][tier]
		"booster":
			offset = Vector2(-44, -3)
			unit = [44.0, 50.0, 56.0, 62.0, 70.0, 82.0][tier]
		"cutter":
			offset = Vector2(14, 0)
			unit = [34.0, 40.0, 44.0, 56.0, 46.0, 56.0][tier]
	var scale_factor := size / unit
	ci.draw_set_transform(centre - offset * scale_factor, 0.0, Vector2(scale_factor, scale_factor))
	match id:
		"craft":
			draw_craft(ci, tier, time)
		"booster":
			draw_booster(ci, tier, 1.0 if tier > 0 else 0.0, time)
		"cutter":
			draw_cutter(ci, tier, Vector2.ZERO, time)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _rect_poly(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
