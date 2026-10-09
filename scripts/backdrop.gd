class_name Backdrop
extends Control
# Everything behind the world: the water gradient, far silhouettes with parallax, light shafts
# and drifting plankton. Drawn in screen space; the run calls follow() every frame.
# Plankton and ridges are computed from the camera position, so they shift as you fly.

var cam := Vector2.ZERO
var zoom := 1.0
var floor_hint := 0.0         # world y of the floor under the camera, to keep ridges on screen
var time := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_noise.seed = 7
	_noise.frequency = 0.0016


func follow(camera_pos: Vector2, camera_zoom: float, floor_y: float, delta: float) -> void:
	cam = camera_pos
	zoom = camera_zoom
	floor_hint = floor_y
	time += delta
	queue_redraw()


func _draw() -> void:
	var palette := Art.zone_palette(cam.x)
	var top: Color = palette["water_top"]
	var bottom: Color = palette["water_bottom"]
	var depth := clampf(cam.y / 14000.0, 0.0, 1.0)
	Art.gradient_rect(self, Rect2(0, 0, 1280, 720), top.lerp(bottom, 0.3 + 0.5 * depth), bottom.darkened(0.2 * depth))
	_light_shafts(palette)
	_ridge(0.12, 0.0, palette, 0.55)
	_ridge(0.28, 1.0, palette, 0.75)
	_ridge(0.5, 2.0, palette, 1.0)
	_plankton(palette)


# Slanted shafts of light from the surface, strongest in shallow water.
func _light_shafts(palette: Dictionary) -> void:
	var strength := clampf(1.0 - cam.y / 3200.0, 0.0, 1.0)
	if strength <= 0.01:
		return
	var accent: Color = palette["accent"]
	for i in 6:
		var wx := i * 330.0 + Art.hash01(i) * 120.0
		var sx := fposmod(wx - cam.x * 0.3, 1900.0) - 300.0
		var sway := sin(time * 0.35 + i) * 40.0
		var width := 70.0 + 50.0 * Art.hash01(i + 9)
		var pts := PackedVector2Array([Vector2(sx + sway, 0), Vector2(sx + sway + width, 0), Vector2(sx + sway + width * 3.0 - 260.0, 720), Vector2(sx + sway - width * 1.2 - 260.0, 720)])
		var c := Color(accent.lightened(0.5), 0.07 * strength)
		var clear := Color(c, 0.0)
		draw_primitive(pts, PackedColorArray([c, c, clear, clear]), PackedVector2Array())


# A far ridge: smooth noise skyline. `factor` is how much it follows the camera (small = far away).
func _ridge(factor: float, layer: float, palette: Dictionary, fade: float) -> void:
	var rock: Color = palette["rock"]
	var accent: Color = palette["accent"]
	var base := clampf(360.0 + (floor_hint - cam.y) * factor * zoom + 100.0 + layer * 30.0, 330.0, 760.0)
	var points := PackedVector2Array()
	var step := 40.0
	var sx := -step
	while sx <= 1280.0 + step:
		var world_x := cam.x * factor + (sx - 640.0) / zoom
		var height := (_noise.get_noise_1d(world_x + layer * 1000.0) * 0.5 + 0.5) * (170.0 + layer * 40.0)
		points.append(Vector2(sx, base - height))
		sx += step
	var fill := rock.lightened(0.04 + 0.03 * layer).lerp(palette["water_bottom"], 0.55 - 0.15 * layer)
	var poly := points.duplicate()
	poly.append(Vector2(1280 + step, 760))
	poly.append(Vector2(-step, 760))
	draw_colored_polygon(poly, Color(fill, fade))
	draw_polyline(points, Color(accent, 0.18 * fade), 2.0, true)


# Floating specks at two depths; they slide past faster the faster you fly.
func _plankton(palette: Dictionary) -> void:
	var accent: Color = palette["accent"]
	for i in 46:
		var near := i % 2 == 0
		var parallax := 0.9 if near else 0.55
		var px := fposmod(Art.hash01(i) * 1500.0 - cam.x * parallax * zoom + sin(time * 0.4 + i) * 12.0, 1400.0) - 60.0
		var py := fposmod(Art.hash01(i + 100) * 900.0 - cam.y * parallax * zoom + time * (6.0 + i % 5), 800.0) - 40.0
		var radius := 1.6 if near else 1.1
		var tone := Color(accent.lightened(0.5), 0.5 if near else 0.28)
		draw_circle(Vector2(px, py), radius, tone)
		if near and i % 6 == 0:
			Art.glow(self, Vector2(px, py), 9.0, Color(accent, 0.25))
