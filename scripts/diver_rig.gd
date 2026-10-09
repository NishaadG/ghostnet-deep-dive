class_name DiverRig
extends Node2D
# Nova, drawn from code: a streamlined diver in a glowing-visor helmet, arms forward and
# legs kicking behind. The owner sets `tiers` (equipped gear), `thrust` and `speed`.
# Used in the dive (child of Player) and in the workshop preview.

const SUIT := Color("2f5aa8")
const SUIT_DARK := Color("1b3568")
const RIM := Color("9fd8ff")

var tiers := {"craft": 0, "booster": 0, "cutter": 0}
var thrust := 0.0           # 0..1, drives the flame and a faster kick
var speed := 0.0            # px/s, drives kick speed
var time := 0.0
var body_scale := 1.25


func _process(delta: float) -> void:
	var kick_rate := 5.0 + clampf(speed / 120.0, 0.0, 6.0) + thrust * 6.0
	time += delta * kick_rate / 5.0
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(body_scale, body_scale))
	var kick := sin(time * 5.0)
	_arm(Vector2(14, 3), Vector2(40, 9), SUIT_DARK)                                  # back arm, behind everything
	_leg(Vector2(-18, 3), -0.38 * kick, SUIT_DARK, Art.CYAN.darkened(0.45))           # back leg
	GearArt.draw_craft(self, tiers["craft"], time)
	GearArt.draw_booster(self, tiers["booster"], thrust, time)
	_tank()
	_torso()
	_leg(Vector2(-18, -1), 0.38 * kick, SUIT, Art.CYAN)                                # front leg
	_helmet()
	_arm(Vector2(16, 3), Vector2(42, 7), SUIT)                                         # front arm
	GearArt.draw_cutter(self, tiers["cutter"], Vector2(43, 7), time)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Twin air tanks on the back (the top of the body).
func _tank() -> void:
	for dx in [-8.0, 2.0]:
		Art.capsule(self, Vector2(dx - 8, -15), Vector2(dx + 8, -15), 5.0, Art.INK)
		Art.capsule(self, Vector2(dx - 8, -15), Vector2(dx + 8, -15), 3.6, Color("7fb4d6"))
	draw_line(Vector2(-14, -17), Vector2(8, -17), Color(1, 1, 1, 0.5), 1.2, true)


func _torso() -> void:
	Art.capsule(self, Vector2(-20, 0), Vector2(20, 0), 11.5, Art.INK)
	Art.capsule(self, Vector2(-20, 0), Vector2(20, 0), 10.0, SUIT)
	draw_line(Vector2(-20, -6), Vector2(18, -6), Color(RIM, 0.7), 2.0, true)           # rim light on top
	draw_line(Vector2(-19, 5), Vector2(16, 5), Art.AMBER, 2.0, true)                   # amber belly stripe
	draw_line(Vector2(-6, -9), Vector2(-6, 9), Color(Art.INK, 0.5), 1.5, true)


# Leg: hip, knee, foot, with a long fin at the end. `swing` rotates the kick.
func _leg(hip: Vector2, swing: float, color: Color, fin_color: Color) -> void:
	var knee := hip + Vector2(-18, 0).rotated(swing)
	var foot := knee + Vector2(-16, 0).rotated(swing * 1.7)
	Art.capsule(self, hip, knee, 5.0, Art.INK)
	Art.capsule(self, knee, foot, 4.5, Art.INK)
	Art.capsule(self, hip, knee, 3.8, color)
	Art.capsule(self, knee, foot, 3.3, color)
	var along := (foot - knee).normalized()
	var side := along.orthogonal()
	Art.shape(self, PackedVector2Array([foot, foot + along * 10 + side * 8, foot + along * 24, foot + along * 10 - side * 8]), fin_color, Art.INK, 1.5)


func _arm(shoulder: Vector2, hand: Vector2, color: Color) -> void:
	Art.capsule(self, shoulder, hand, 5.0, Art.INK)
	Art.capsule(self, shoulder, hand, 3.8, color)


func _helmet() -> void:
	var c := Vector2(24, -2)
	Art.glow(self, c + Vector2(6, 0), 26.0, Color(Art.CYAN, 0.35))
	draw_circle(c, 13.5, Art.INK)
	draw_circle(c, 12.0, Color("3a68b8"))
	var visor := PackedVector2Array()
	for i in 12:
		var a := -PI / 2.3 + PI / 1.15 * i / 11.0
		visor.append(c + Vector2(cos(a) * 8.0 + 4.0, sin(a) * 9.0))
	draw_colored_polygon(visor, Color(Art.CYAN, 0.95))
	draw_polyline(visor, Color.WHITE, 1.4, true)
	draw_arc(c + Vector2(-1, -1), 9.5, PI * 1.15, PI * 1.62, 8, Color(1, 1, 1, 0.6), 1.8, true)
