class_name Figure
extends Node2D
# A standing character for cutscenes, drawn from code in the same outlined vector style as Nova.
# The origin is at the feet. No faces in detail: a skin-tone head, two dot eyes and a hat or helmet
# are enough to tell people apart, and they keep the art consistent with the rest of the game.
#   kind: "captain" (Captain Vale), "ilo" (deckhand), "harbour" (harbourmaster), "nova" (in her suit)

var kind := "captain"
var facing := 1.0            # 1 = looking right, -1 = looking left
var speaking := false        # set by the cutscene: the speaker bobs a little and glows
var _time := randf() * 10.0
var _talk := 0.0

const SKIN := {"captain": Color("b9825a"), "ilo": Color("8a5a3c"), "harbour": Color("d9a77f"), "nova": Color("c48a62")}


func _process(delta: float) -> void:
	_time += delta
	_talk = move_toward(_talk, 1.0 if speaking else 0.0, delta * 4.0)
	queue_redraw()


func _draw() -> void:
	var breathe := sin(_time * 1.6) * 1.5
	var bob := absf(sin(_time * 9.0)) * 3.0 * _talk
	if _talk > 0.0:
		Art.glow(self, Vector2(0, -120), 150.0, Color(_accent(), 0.12 * _talk))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0))
	match kind:
		"captain": _captain(breathe, bob)
		"ilo": _ilo(breathe, bob)
		"harbour": _harbour(breathe, bob)
		"nova": _nova(breathe, bob)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _accent() -> Color:
	return {"captain": Art.AMBER, "ilo": Color("ffe14a"), "harbour": Art.VIOLET, "nova": Art.MAGENTA}.get(kind, Art.CYAN)


# ---- Shared body parts ----

func _legs(color: Color, boots: Color) -> void:
	for x in [-12.0, 12.0]:
		Art.capsule(self, Vector2(x, -88), Vector2(x, -10), 9.5, Art.INK)
		Art.capsule(self, Vector2(x, -88), Vector2(x, -10), 8.0, color)
		Art.shape(self, PackedVector2Array([Vector2(x - 10, -14), Vector2(x + 14, -14), Vector2(x + 16, 0), Vector2(x - 10, 0)]), boots, Art.INK, 2.0)


func _head(centre: Vector2, skin: Color) -> void:
	draw_circle(centre, 23.0, Art.INK)
	draw_circle(centre, 21.0, skin)
	draw_circle(centre + Vector2(7, -2), 2.6, Art.INK)             # the eye on the side we face
	draw_circle(centre + Vector2(16, -2), 2.4, Art.INK)
	draw_line(centre + Vector2(6, 9), centre + Vector2(15, 9), Color(Art.INK, 0.7), 2.0, true)


func _arm(shoulder: Vector2, hand: Vector2, sleeve: Color, skin: Color) -> void:
	Art.capsule(self, shoulder, hand, 8.5, Art.INK)
	Art.capsule(self, shoulder, hand, 7.0, sleeve)
	draw_circle(hand, 7.5, Art.INK)
	draw_circle(hand, 6.0, skin)


# ---- The characters ----

# Captain Vale: long navy coat with an orange belt, captain's cap with a gold badge.
func _captain(breathe: float, bob: float) -> void:
	var coat := Color("1b2547")
	_legs(Color("141a33"), Color("0b0f20"))
	var top := -190.0 + breathe - bob
	_arm(Vector2(-22, top + 22), Vector2(-30, -78), coat.darkened(0.2), SKIN["captain"])
	Art.shape(self, PackedVector2Array([Vector2(-30, top + 10), Vector2(30, top + 10), Vector2(40, -40), Vector2(-40, -40)]), coat, Color("3a4a80"), 2.5)
	draw_line(Vector2(-37, -100), Vector2(37, -100), Color("ff7a2a"), 6.0, true)                    # belt
	draw_line(Vector2(0, top + 12), Vector2(0, -42), Color(Art.INK, 0.6), 2.0, true)
	for y in [top + 40, top + 70]:
		draw_circle(Vector2(8, y), 3.0, Art.AMBER)
	_arm(Vector2(22, top + 22), Vector2(34, -86), coat, SKIN["captain"])
	var head := Vector2(0, top - 18)
	_head(head, SKIN["captain"])
	draw_rect(Rect2(head + Vector2(-25, -22), Vector2(50, 12)), Color("1b2547"))                  # cap
	Art.shape(self, PackedVector2Array([head + Vector2(-22, -22), head + Vector2(-16, -40), head + Vector2(18, -40), head + Vector2(24, -22)]), coat, Color("3a4a80"), 2.0)
	draw_line(head + Vector2(-26, -12), head + Vector2(34, -12), Art.INK, 5.0, true)                 # brim
	Art.glow(self, head + Vector2(2, -30), 14.0, Color(Art.AMBER, 0.6))
	draw_circle(head + Vector2(2, -30), 5.0, Color("ffd34a"))


# Ilo the deckhand: yellow oilskin with reflective stripes and a hood.
func _ilo(breathe: float, bob: float) -> void:
	var slicker := Color("f2c21b")
	_legs(Color("2a3350"), Color("15192a"))
	var top := -180.0 + breathe - bob
	_arm(Vector2(-22, top + 20), Vector2(-26, -84), slicker.darkened(0.15), SKIN["ilo"])
	Art.shape(self, PackedVector2Array([Vector2(-28, top + 8), Vector2(28, top + 8), Vector2(34, -70), Vector2(-34, -70)]), slicker, Color("fff08a"), 2.5)
	for y in [top + 46, top + 70]:
		draw_line(Vector2(-31, y), Vector2(31, y), Color("e8f4ff"), 6.0, true)
	_arm(Vector2(22, top + 20), Vector2(40, top - 10), slicker, SKIN["ilo"])          # one arm up, waving at the net
	var head := Vector2(0, top - 16)
	draw_circle(head, 28.0, Art.INK)
	draw_circle(head, 26.0, slicker.darkened(0.1))                                    # hood
	_head(head + Vector2(3, 2), SKIN["ilo"])


# The harbourmaster: violet jacket, a clipboard and round glasses.
func _harbour(breathe: float, bob: float) -> void:
	var jacket := Color("3b2d6b")
	_legs(Color("1f2140"), Color("101225"))
	var top := -184.0 + breathe - bob
	_arm(Vector2(-22, top + 22), Vector2(-28, -84), jacket.darkened(0.2), SKIN["harbour"])
	Art.shape(self, PackedVector2Array([Vector2(-30, top + 10), Vector2(30, top + 10), Vector2(34, -76), Vector2(-34, -76)]), jacket, Color("6a58b8"), 2.5)
	draw_line(Vector2(0, top + 14), Vector2(0, -78), Color(Art.ICE, 0.35), 2.0, true)
	Art.shape(self, PackedVector2Array([Vector2(16, top + 40), Vector2(50, top + 36), Vector2(54, top + 84), Vector2(20, top + 88)]), Color("d9e2ea"), Art.INK, 2.0)   # clipboard
	for k in 3:
		draw_line(Vector2(24, top + 52 + k * 10), Vector2(46, top + 49 + k * 10), Color(Art.INK, 0.6), 1.5, true)
	_arm(Vector2(22, top + 22), Vector2(30, top + 70), jacket, SKIN["harbour"])
	var head := Vector2(0, top - 18)
	_head(head, SKIN["harbour"])
	draw_arc(head + Vector2(-2, -12), 20.0, PI, TAU, 12, Color("cfd6e0"), 6.0, true)               # grey hair
	for x in [7.0, 16.0]:
		draw_arc(head + Vector2(x, -2), 5.5, 0.0, TAU, 10, Art.ICE, 1.6, true)                    # glasses


# Nova on the dock in her dive suit (same colours as the diver in the game), helmet on.
func _nova(breathe: float, bob: float) -> void:
	_legs(DiverRig.SUIT_DARK, Color("ff7a2a"))
	var top := -176.0 + breathe - bob
	Art.capsule(self, Vector2(-24, top + 16), Vector2(-24, top + 74), 12.0, Art.INK)                # air tank
	Art.capsule(self, Vector2(-24, top + 16), Vector2(-24, top + 74), 10.0, Color("ff8a3a"))
	_arm(Vector2(-18, top + 20), Vector2(-22, -84), DiverRig.SUIT_DARK, Color("ff7a2a"))
	Art.shape(self, PackedVector2Array([Vector2(-22, top + 8), Vector2(24, top + 8), Vector2(26, -80), Vector2(-24, -80)]), DiverRig.SUIT, DiverRig.RIM, 2.5)
	draw_line(Vector2(-22, top + 56), Vector2(24, top + 56), Art.AMBER, 4.0, true)
	_arm(Vector2(18, top + 20), Vector2(36, top + 58), DiverRig.SUIT, Color("ff7a2a"))
	var head := Vector2(2, top - 16)
	Art.glow(self, head, 50.0, Color(Art.CYAN, 0.3))
	draw_circle(head, 26.0, Art.INK)
	draw_circle(head, 24.0, Color("3a68b8"))
	draw_circle(head + Vector2(5, 1), 17.0, Color(Art.CYAN, 0.9))                                  # visor
	_head_inside_visor(head + Vector2(5, 3))
	draw_arc(head + Vector2(-2, -4), 19.0, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.6), 2.5, true)


func _head_inside_visor(centre: Vector2) -> void:
	draw_circle(centre, 12.0, SKIN["nova"])
	draw_arc(centre + Vector2(0, -3), 12.0, PI * 0.95, TAU * 1.01, 12, Color("ff5fb0"), 6.0, true)   # pink hair, as in the comic
	draw_circle(centre + Vector2(4, 0), 1.8, Art.INK)
	draw_circle(centre + Vector2(10, 0), 1.8, Art.INK)
