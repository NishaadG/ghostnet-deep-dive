class_name Pickup
extends Node2D
# Something Nova can fly through: an O2 canister, a fuel cell, or a bit of plastic.
# Drawn from code. Plastic is dim and spins; useful pickups glow and bob.

var kind := "o2"          # "o2", "fuel" or "junk"
var radius := 45.0
var collected := false

var _variant := randi() % 3
var _phase := randf() * TAU
var _age := 0.0


func setup(new_kind: String) -> void:
	kind = new_kind
	if kind == "junk":
		radius = 36.0


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func collect() -> void:
	collected = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.7, 1.7), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	match kind:
		"o2":
			_canister(Art.CYAN, "O2")
		"fuel":
			_canister(Art.AMBER, "")
		_:
			_junk()


# A rounded capsule with a glowing aura and a pulsing ring.
func _canister(color: Color, label: String) -> void:
	var bob := Vector2(0, sin(_age * 2.0 + _phase) * 7.0)
	var pulse := 0.5 + 0.5 * sin(_age * 3.0 + _phase)
	Art.glow(self, bob, 70.0, Color(color, 0.30 + 0.15 * pulse))
	draw_arc(bob, 38.0 + pulse * 4.0, 0.0, TAU, 28, Color(color, 0.5 - 0.25 * pulse), 2.0, true)
	Art.capsule(self, bob + Vector2(0, -14), bob + Vector2(0, 14), 17.0, Art.INK)
	Art.capsule(self, bob + Vector2(0, -14), bob + Vector2(0, 14), 14.5, color.darkened(0.5))
	Art.capsule(self, bob + Vector2(-5, -12), bob + Vector2(-5, 12), 3.0, Color(color.lightened(0.6), 0.8))
	if label != "":
		draw_string(Game.font_bold, bob + Vector2(-14, 6), label, HORIZONTAL_ALIGNMENT_CENTER, 28, 16, Art.ICE)
	else:                                                   # a bolt for fuel
		draw_colored_polygon(PackedVector2Array([bob + Vector2(3, -14), bob + Vector2(-7, 2), bob + Vector2(-1, 2), bob + Vector2(-3, 14), bob + Vector2(8, -3), bob + Vector2(1, -3)]), Art.ICE)


# Three bits of plastic: a bottle, a bag and a ring from a can pack.
func _junk() -> void:
	draw_set_transform(Vector2.ZERO, _age * 0.6 + _phase, Vector2.ONE)
	var tone := Color("86a7b8", 0.75)
	match _variant:
		0:   # bottle
			Art.shape(self, PackedVector2Array([Vector2(-8, -22), Vector2(8, -22), Vector2(8, -10), Vector2(12, -2), Vector2(12, 22), Vector2(-12, 22), Vector2(-12, -2), Vector2(-8, -10)]), Color(tone, 0.45), tone, 1.5)
			draw_line(Vector2(-6, -26), Vector2(6, -26), Art.MAGENTA, 3.0, true)
		1:   # bag
			Art.shape(self, PackedVector2Array([Vector2(-18, -16), Vector2(18, -18), Vector2(14, 6), Vector2(22, 20), Vector2(-4, 14), Vector2(-20, 20), Vector2(-12, 2)]), Color(tone, 0.3), tone, 1.5)
		_:   # six-pack ring
			for dx in [-12.0, 12.0]:
				draw_arc(Vector2(dx, 0), 9.0, 0.0, TAU, 14, tone, 2.0, true)
			draw_line(Vector2(-3, 0), Vector2(3, 0), tone, 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
