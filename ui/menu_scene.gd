class_name MenuScene
extends Control
# The living background of every menu: the reef at dusk with light shafts, a drifting ghost net,
# glowing corals along the seabed, and Nova gliding past with Pip. Pure decoration.

var dim := 0.0                  # 0..1 darkens the scene so panels on top stay readable
var show_diver := true
var _backdrop: Backdrop
var _diver: DiverRig
var _net: Net
var _time := 0.0
var _floor_points := PackedVector2Array()
var _seabed: Control
var _veil: Control


func _ready() -> void:
	size = Vector2(1280, 720)
	_backdrop = Backdrop.new()
	add_child(_backdrop)
	for i in 30:                                   # a gently rolling seabed
		_floor_points.append(Vector2(-60 + i * 50.0, 640.0 + sin(i * 0.55) * 24.0 + sin(i * 1.3) * 8.0))
	_seabed = Control.new()                        # drawn after the backdrop, before the net and diver
	_seabed.size = size
	_seabed.draw.connect(_draw_seabed)
	add_child(_seabed)
	_net = Net.new()
	_net.setup(2, false)
	_net.position = Vector2(900, 250)
	add_child(_net)
	if show_diver:
		_diver = DiverRig.new()
		_diver.tiers = {"craft": Game.level("craft"), "booster": Game.level("booster"), "cutter": Game.level("cutter")}
		_diver.speed = 300.0
		add_child(_diver)
	_veil = Control.new()
	_veil.size = size
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.draw.connect(func(): _veil.draw_rect(Rect2(0, 0, 1280, 720), Color(Art.INK, dim)))
	add_child(_veil)


func _process(delta: float) -> void:
	_time += delta
	_backdrop.follow(Vector2(_time * 55.0, 520.0), 1.0, 900.0, delta)
	_net.position = Vector2(950 + sin(_time * 0.25) * 70.0, 240 + sin(_time * 0.4) * 30.0)
	if _diver:
		var t := fposmod(_time * 0.06, 1.0)
		_diver.position = Vector2(-120 + t * 1500.0, 400.0 + sin(_time * 0.9) * 36.0)
		_diver.rotation = cos(_time * 0.9) * 0.12
	_seabed.queue_redraw()
	_veil.queue_redraw()


func _draw_seabed() -> void:
	# Seabed silhouette and corals, drawn after the backdrop child but beneath the net and diver.
	var rock := Color("0b2d44")
	var poly := _floor_points.duplicate()
	poly.append(Vector2(1400, 760))
	poly.append(Vector2(-60, 760))
	Art.gradient_rect(_seabed, Rect2(0, 600, 1280, 120), Color("0f3d52"), Color("041420"))
	_seabed.draw_colored_polygon(poly, rock)
	_seabed.draw_polyline(_floor_points, Color(Art.CYAN, 0.7), 2.5, true)
	for i in 9:
		var x := 60.0 + i * 150.0 + Art.hash01(i) * 60.0
		DecorArt.coral(_seabed, Vector2(x, 650.0 + sin(x * 0.01) * 12.0), 90.0 + 70.0 * Art.hash01(i + 9), i * 13 + 5, i, true, _time)
