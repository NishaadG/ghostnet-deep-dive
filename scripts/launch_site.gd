class_name LaunchSite
extends Node2D
# The world above the water: a dusk sky with a low sun and a far city, the animated water
# surface, and Boat 07 with its launch ramp. A taller Launch Ramp upgrade builds a taller ramp.

var cam_x := 0.0
var cam_y := 0.0
var ramp_level := 0
var time := 0.0


func follow(camera_pos: Vector2, delta: float) -> void:
	cam_x = camera_pos.x
	cam_y = camera_pos.y
	time += delta
	visible = cam_y < 700.0           # nothing to see once we are deep
	if visible:
		queue_redraw()


func _draw() -> void:
	var left := cam_x - 1500.0
	var right := cam_x + 1500.0
	# Sky: indigo at the top, magenta and amber toward the horizon.
	Art.gradient_rect(self, Rect2(left, -3200, right - left, 1900), Color("0b1030"), Color("3a1b5e"))
	Art.gradient_rect(self, Rect2(left, -1300, right - left, 900), Color("3a1b5e"), Color("c4457a"))
	Art.gradient_rect(self, Rect2(left, -400, right - left, 400), Color("c4457a"), Color("ffb06a"))
	for i in 40:                                           # a few stars in the dark part
		var sx := left + fposmod(Art.hash01(i) * 3000.0 - cam_x * 0.05, 3000.0)
		draw_circle(Vector2(sx, -2400.0 + Art.hash01(i + 50) * 1300.0), 1.5, Color(1, 1, 1, 0.5))
	# Low sun and far city silhouette, both slow parallax.
	var sun := Vector2(cam_x * 0.9 + 700.0, -150.0)
	Art.glow(self, sun, 420.0, Color("ffd08a", 0.5))
	draw_circle(sun, 90.0, Color("ffe6b0"))
	_far_city(cam_x * 0.8)
	_water_surface(left, right)
	_boat()


func _far_city(origin: float) -> void:
	var base := 0.0
	for i in 18:
		var x := origin - 1700.0 + i * 190.0
		var h := 120.0 + 260.0 * Art.hash01(i * 3)
		draw_rect(Rect2(x, base - h, 140, h), Color("1a1840"))
		for r in int(h / 40.0):
			if Art.hash01(i * 11 + r) < 0.35:
				draw_rect(Rect2(x + 14 + 36 * (r % 3), base - h + 14 + r * 36, 10, 14), Color(Art.AMBER, 0.7))


# The surface is a bright animated line with a soft translucent band under it.
func _water_surface(left: float, right: float) -> void:
	var line := PackedVector2Array()
	var x := left
	while x <= right:
		line.append(Vector2(x, sin(x * 0.012 + time * 1.6) * 5.0 + sin(x * 0.031 + time * 2.3) * 2.5))
		x += 36.0
	var band := line.duplicate()
	band.append(Vector2(right, 90.0))
	band.append(Vector2(left, 90.0))
	draw_primitive(PackedVector2Array([Vector2(left, 0), Vector2(right, 0), Vector2(right, 140), Vector2(left, 140)]),
			PackedColorArray([Color(1, 0.8, 0.8, 0.22), Color(1, 0.8, 0.8, 0.22), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]), PackedVector2Array())
	draw_polyline(line, Color(1, 0.9, 0.85, 0.25), 12.0, true)
	draw_polyline(line, Color(1, 0.95, 0.9, 0.95), 2.5, true)


func _boat() -> void:
	var bob := sin(time * 1.2) * 3.0
	var deck := -150.0 + bob
	var hull := PackedVector2Array([Vector2(-760, deck), Vector2(-40, deck), Vector2(-4, 6), Vector2(-690, 6), Vector2(-780, deck - 30)])
	Art.shape(self, hull, Color("0f1a3a"), Color("3a5a9c"), 3.0)
	draw_line(Vector2(-745, deck + 24), Vector2(-52, deck + 24), Art.AMBER, 4.0, true)       # hull stripe
	draw_string(Game.font_bold, Vector2(-520, deck + 86), "07", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(Art.ICE, 0.85))
	# Cabin, mast and a beacon.
	Art.shape(self, PackedVector2Array([Vector2(-560, deck), Vector2(-560, deck - 90), Vector2(-420, deck - 90), Vector2(-380, deck)]), Color("1c2c58"), Color("3a5a9c"), 2.5)
	draw_rect(Rect2(-535, deck - 70, 36, 26), Color(Art.AMBER, 0.85))
	draw_rect(Rect2(-480, deck - 70, 36, 26), Color(Art.AMBER, 0.85))
	draw_line(Vector2(-490, deck - 90), Vector2(-490, deck - 170), Color("3a5a9c"), 3.0, true)
	var blink := 0.5 + 0.5 * sin(time * 3.0)
	Art.glow(self, Vector2(-490, deck - 172), 30.0, Color(Art.MAGENTA, 0.4 + 0.4 * blink))
	draw_circle(Vector2(-490, deck - 172), 4.0, Art.MAGENTA)
	# Ramp: a beam down to the stern, held up by posts. Taller ramp, taller posts.
	var start := Balance.ramp_start(ramp_level)
	var end := Balance.RAMP_END
	draw_line(start + Vector2(-30, 14), end + Vector2(0, 14), Color("2a4170"), 14.0, true)
	draw_line(start + Vector2(-30, 8), end + Vector2(0, 8), Art.CYAN, 2.5, true)
	for t in [0.2, 0.55, 0.9]:
		var p := start.lerp(end, t) + Vector2(0, 20)
		draw_line(p, Vector2(p.x, deck), Color("2a4170"), 6.0, true)
	draw_line(end + Vector2(0, 14), end + Vector2(-50, 200), Color("2a4170"), 8.0, true)
