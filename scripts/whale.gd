class_name Whale
extends Node2D
# The Lumen, a giant whale facing left (toward Nova), pinned behind the last net wall.
# `lit` goes 0 -> 1 when she is freed: she brightens and her bioluminescence switches on.
# `wrapped` goes 1 -> 0 at the same time: the ghost nets wrapped around her body fall away.

const LENGTH := 1200.0
const HEIGHT := 440.0

var lit := 0.0
var wrapped := 0.0

# Net patches over her body: centre and radii in px. Together they stand for the 41 nets.
const NET_PATCHES := [[Vector2(-380, -10), Vector2(170, 130)], [Vector2(-120, -30), Vector2(190, 150)],
		[Vector2(140, 0), Vector2(170, 120)], [Vector2(360, 10), Vector2(130, 90)], [Vector2(-240, 120), Vector2(140, 80)]]
var _age := 0.0


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _outline() -> PackedVector2Array:
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in 21:
		var u := i / 20.0
		var thickness := HEIGHT * 0.5 * pow(sin(PI * pow(u, 0.72)), 0.85) * (1.0 - 0.55 * u)
		var x := -LENGTH / 2.0 + u * LENGTH
		var tail_swish := sin(_age * 0.9 - u * 3.0) * 26.0 * u * u
		top.append(Vector2(x, -thickness * 0.85 + tail_swish))
		bottom.append(Vector2(x, thickness * 1.1 + tail_swish))
	bottom.reverse()
	top.append_array(bottom)
	return top


func _draw() -> void:
	var body := Color("1a2a40").lerp(Color("2b78a8"), lit)
	var edge := Color("33506f").lerp(Art.CYAN, lit)
	Art.glow(self, Vector2.ZERO, 900.0, Color(Art.CYAN, 0.18 * lit))
	var tail := Vector2(LENGTH / 2.0, sin(_age * 0.9 - 3.0) * 26.0)
	for side in [-1.0, 1.0]:                                          # flukes
		Art.shape(self, PackedVector2Array([tail + Vector2(-40, 0), tail + Vector2(90, 140 * side), tail + Vector2(30, 20 * side)]), body.darkened(0.15), edge, 3.0)
	Art.shape(self, _outline(), body, edge, 4.0)
	Art.shape(self, PackedVector2Array([Vector2(-120, 120), Vector2(100, 280), Vector2(60, 110)]), body.darkened(0.2), edge, 3.0)   # pectoral fin
	for k in 9:                                                       # belly pleats
		var x := -LENGTH * 0.38 + k * 52.0
		draw_line(Vector2(x, 130), Vector2(x + 24, 190), Color(edge, 0.5), 2.0, true)
	draw_circle(Vector2(-LENGTH * 0.38, -20), 13.0, Color("070d1a"))                       # eye
	draw_circle(Vector2(-LENGTH * 0.38 + 3, -23), 4.0, Color(Art.ICE, 0.4 + 0.6 * lit))
	draw_arc(Vector2(-LENGTH * 0.2, 60), 170.0, 0.05 * PI, 0.55 * PI, 16, Color(edge, 0.7), 3.0, true)   # mouth line
	for i in 34:                                                      # bioluminescent spots along the flank
		var u := 0.08 + 0.85 * Art.hash01(i)
		var spot := Vector2(-LENGTH / 2.0 + u * LENGTH, -HEIGHT * 0.22 * (1.0 - u * 0.5) + Art.hash01(i + 40) * 120.0 - 40.0)
		var twinkle := 0.5 + 0.5 * sin(_age * 2.0 + i)
		Art.glow(self, spot, 18.0 + 14.0 * twinkle, Color(Art.CYAN, (0.15 + 0.6 * twinkle) * lit))
		draw_circle(spot, 3.0, Color(Art.ICE, (0.15 + 0.85 * lit)))
	if wrapped > 0.0:
		_nets()


# Mesh drawn inside each ellipse: two families of slanted strands, plus amber floats on top.
func _nets() -> void:
	var mesh := Color(Art.NET_COLOR, 0.75 * wrapped)
	for i in NET_PATCHES.size():
		var centre: Vector2 = NET_PATCHES[i][0] + Vector2(0, sin(_age * 0.9 + i) * 6.0)
		var radii: Vector2 = NET_PATCHES[i][1]
		for direction in [Vector2(1, 1).normalized(), Vector2(1, -1).normalized()]:
			var across: Vector2 = direction.orthogonal()
			var d := -0.92
			while d < 0.95:
				var half := sqrt(1.0 - d * d)          # half-length of this strand inside a unit circle
				var a: Vector2 = (across * d - direction * half) * radii + centre
				var b: Vector2 = (across * d + direction * half) * radii + centre
				draw_line(a, b, mesh, 1.6, true)
				d += 0.16
		for k in 5:
			var angle := PI * 1.15 + k * 0.32
			var float_pos := centre + Vector2(cos(angle), sin(angle)) * radii
			Art.glow(self, float_pos, 14.0, Color(Art.AMBER, 0.45 * wrapped))
			draw_circle(float_pos, 5.0, Color(Art.AMBER, wrapped))
