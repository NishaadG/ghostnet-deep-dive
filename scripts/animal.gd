class_name Animal
extends Node2D
# A sea turtle or a small fish, drawn from code. Trapped animals are dull and shake;
# once freed they turn bright, swim away and fade.

var kind := "turtle"          # "turtle" or "fish"
var trapped := true
var body_scale := 1.0
var color := Color("6d8a99")
var time := randf() * 10.0


func setup(animal_kind: String, scale_factor: float) -> void:
	kind = animal_kind
	body_scale = scale_factor


func free_swim(away: Vector2) -> void:
	trapped = false
	color = Color("5fe3c0") if kind == "turtle" else Color("ffb84a")
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position", position + away, 1.6).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 1.6)
	var bubbles := CPUParticles2D.new()
	bubbles.amount = 14
	bubbles.lifetime = 0.9
	bubbles.gravity = Vector2(0, -50)
	bubbles.initial_velocity_max = 20.0
	bubbles.scale_amount_min = 2.0
	bubbles.scale_amount_max = 4.0
	bubbles.color = Color(Art.ICE, 0.6)
	add_child(bubbles)


func _process(delta: float) -> void:
	time += delta * (6.0 if trapped else 3.0)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(randf_range(-2, 2), randf_range(-2, 2)) if trapped else Vector2.ZERO, 0.0, Vector2(body_scale, body_scale))
	if kind == "turtle":
		_turtle()
	else:
		_fish()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _turtle() -> void:
	var flap := sin(time) * 0.35
	var shell := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		shell.append(Vector2(cos(a) * 46.0, sin(a) * 30.0))
	if not trapped:
		Art.glow(self, Vector2.ZERO, 90.0, Color(color, 0.35))
	for side in [-1.0, 1.0]:                                  # flippers
		Art.shape(self, PackedVector2Array([Vector2(14 * side, 10), Vector2(40 * side, 34).rotated(flap * side), Vector2(28 * side, 8)]), color.darkened(0.2), Art.INK, 1.5)
	Art.shape(self, PackedVector2Array([Vector2(44, -4), Vector2(66, 0), Vector2(46, 8)]), color.lightened(0.1), Art.INK, 1.5)   # head
	draw_circle(Vector2(58, -1), 2.0, Art.INK)
	Art.shape(self, shell, color.darkened(0.25), Art.INK, 2.0)
	for q in [Vector2(-18, -6), Vector2(2, -10), Vector2(20, -4), Vector2(-8, 10), Vector2(14, 12)]:     # shell plates
		draw_arc(q, 8.0, 0.0, TAU, 6, Color(color.lightened(0.3), 0.7), 1.5, true)


func _fish() -> void:
	var wag := sin(time) * 5.0
	var body := PackedVector2Array([Vector2(-14, 0), Vector2(-4, -9), Vector2(10, -8), Vector2(18, 0), Vector2(10, 8), Vector2(-4, 9)])
	if not trapped:
		Art.glow(self, Vector2.ZERO, 40.0, Color(color, 0.4))
	Art.shape(self, PackedVector2Array([Vector2(-12, 0), Vector2(-26, -9 + wag), Vector2(-26, 9 + wag)]), color.darkened(0.25), Art.INK, 1.5)
	Art.shape(self, body, color, Art.INK, 1.5)
	draw_circle(Vector2(11, -2), 2.0, Art.INK)
