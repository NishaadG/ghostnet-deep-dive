class_name Run
extends Node2D
# One dive. Builds the world, follows Nova with the camera, tracks stats, and reports
# a result dictionary through `finished` once Pip has towed her back up.

signal finished(result: Dictionary)

const TOW_DELAY := 1.4   # seconds between the run ending and handing over to the next screen

var stats: Dictionary
var player: Player
var terrain: Terrain
var camera: Camera2D
var max_depth_m := 0.0
var top_speed := 0.0
var end_reason := ""
var ended := false
var _tow_timer := 0.0
var _shake := 0.0
var _info: Label
var _banner: Label


func _ready() -> void:
	stats = Balance.stats_for(Game.levels)
	terrain = Terrain.new()
	terrain.setup(randi())
	add_child(terrain)
	add_child(LaunchSite.new())
	player = Player.new()
	add_child(player)
	player.start(stats, terrain)
	player.ended.connect(_on_player_ended)
	player.hit_floor.connect(func(into_speed: float): _shake = maxf(_shake, clampf(into_speed / 40.0, 3.0, 14.0)))
	player.hit_ceiling.connect(func(): _shake = maxf(_shake, 8.0))
	camera = Camera2D.new()
	camera.position = player.position
	add_child(camera)
	camera.make_current()
	_build_debug_hud()
	terrain.update(camera.position.x)


func _process(delta: float) -> void:
	_follow_with_camera(delta)
	if not ended:
		max_depth_m = maxf(max_depth_m, player.position.y / Balance.PX_PER_M)
		top_speed = maxf(top_speed, player.vel.length())
	else:
		_tow_timer += delta
		if _tow_timer >= TOW_DELAY:
			set_process(false)
			finished.emit(make_result())
	_update_debug_hud()


# Camera leads in the direction of travel and zooms out a little when fast.
func _follow_with_camera(delta: float) -> void:
	var lead := (player.vel * 0.3).limit_length(320.0)
	camera.position = camera.position.lerp(player.position + lead, 1.0 - exp(-6.0 * delta))
	var zoom_target := lerpf(1.0, 0.7, clampf(player.vel.length() / 1100.0, 0.0, 1.0))
	camera.zoom = camera.zoom.lerp(Vector2(zoom_target, zoom_target), 1.0 - exp(-2.0 * delta))
	_shake = maxf(0.0, _shake - 40.0 * delta)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	terrain.view_half = 640.0 / camera.zoom.x + 300.0
	terrain.update(camera.position.x)
	# The deeper Nova goes, the darker the water.
	var depth := clampf(player.position.y / 30000.0, 0.0, 1.0)
	RenderingServer.set_default_clear_color(Color(0.08, 0.35, 0.45).lerp(Color(0.01, 0.02, 0.05), sqrt(depth)))


func make_result() -> Dictionary:
	return {
		"reason": end_reason,
		"distance_m": maxf(0.0, player.position.x / Balance.PX_PER_M),
		"max_depth_m": max_depth_m,
		"top_speed": top_speed,
	}


func _on_player_ended(reason: String) -> void:
	ended = true
	end_reason = reason
	var text: String = {
		"oxygen": "Out of oxygen",
		"crash": "Hit the seabed too hard",
		"rest": "Came to rest on the seabed",
	}.get(reason, reason)
	_banner.text = "%s. Pip is towing you up..." % text
	_banner.visible = true


# ---- Temporary readout, replaced by the real HUD in milestone 2 ----

func _build_debug_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_info = Label.new()
	_info.position = Vector2(16, 12)
	layer.add_child(_info)
	_banner = Label.new()
	_banner.position = Vector2(16, 120)
	_banner.visible = false
	layer.add_child(_banner)


func _update_debug_hud() -> void:
	_info.text = "Distance %d m   Depth %d m   Speed %d px/s\nOxygen %.1f s   Fuel %.1f s   Angle %d" % [
		maxf(0.0, player.position.x / Balance.PX_PER_M), maxf(0.0, player.position.y / Balance.PX_PER_M),
		player.vel.length(), player.oxygen, player.fuel, rad_to_deg(player.angle)]
