class_name Pip
extends Node2D
# Pip, the drone. It follows Nova with a lerp and a bob, and its colour is the oxygen warning:
# cyan is fine, amber under 35%, red under 15%. At Pip level 3 a small arrow shows the way to the next O2.

var player: Player
var spawner: Spawner
var stats: Dictionary
var _age := 0.0


func _process(delta: float) -> void:
	if player == null:
		return
	_age += delta
	var target := player.position + Vector2(-70, -55) + Vector2(0, sin(_age * 2.5) * 8.0)
	position = position.lerp(target, 1.0 - exp(-12.0 * delta))
	position = player.position + (position - player.position).limit_length(120.0)     # never lag far behind a fast dive
	queue_redraw()


func oxygen_fraction() -> float:
	return player.oxygen / stats["max_oxygen"]


func _draw() -> void:
	var fraction := oxygen_fraction()
	var color := Art.CYAN
	if fraction < 0.15:
		color = Color("ff4a4a")
	elif fraction < 0.35:
		color = Art.AMBER
	var blink := 0.5 + 0.5 * sin(_age * (12.0 if fraction < 0.15 else 3.0))
	Art.glow(self, Vector2.ZERO, 90.0, Color(color, 0.22 + 0.1 * blink))
	for side in [-1.0, 1.0]:                                           # little fins
		Art.shape(self, PackedVector2Array([Vector2(0, 4 * side), Vector2(-16, 14 * side), Vector2(-4, 2 * side)]), Color("2a3f66"), Art.INK, 1.5)
	draw_circle(Vector2.ZERO, 14.0, Art.INK)
	draw_circle(Vector2.ZERO, 12.0, Color("2a3f66"))
	draw_arc(Vector2.ZERO, 12.0, PI * 1.1, PI * 1.7, 8, Color(1, 1, 1, 0.45), 2.0, true)
	draw_circle(Vector2(4, 0), 6.5, Art.INK)
	draw_circle(Vector2(4, 0), 5.0, color)
	draw_circle(Vector2(5.5, -1.5), 1.6, Color.WHITE)
	if stats.get("pip_arrow", false) and spawner != null:
		_arrow(color)


func _arrow(color: Color) -> void:
	var best: Pickup = null
	for pickup in spawner.pickups:
		if pickup.kind == "o2" and not pickup.collected and pickup.position.x > player.position.x:
			if best == null or pickup.position.x < best.position.x:
				best = pickup
	if best == null:
		return
	var direction := (best.position - global_position).normalized()
	var tip := direction * 44.0
	var left := direction.rotated(2.6) * 12.0
	var right := direction.rotated(-2.6) * 12.0
	draw_colored_polygon(PackedVector2Array([tip, tip + left, tip + right]), Color(Art.CYAN, 0.9))
