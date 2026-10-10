class_name Run
extends Node2D
# One dive. Builds the world, follows Nova with the camera, tracks stats, handles net walls,
# and reports a result dictionary through `finished` once Pip has towed her back up.

signal finished(result: Dictionary)
signal story_moment(scene_id: String)   # main pauses the dive and plays this cutscene, then resumes

const MEET_DISTANCE := 650.0   # px before a wall where its first-meeting cutscene starts

const TOW_DELAY := 1.6   # seconds between the run ending and handing over to the next screen
const DARKNESS_SHADER := """
shader_type canvas_item;
uniform vec2 pip_uv = vec2(0.5, 0.5);
uniform float darkness = 0.0;
uniform float radius = 0.36;
uniform vec3 lights[8];          // glowing creatures: xy = screen position (0..1), z = light radius (0 = off)
void fragment() {
	vec2 aspect = vec2(1.7778, 1.0);
	float d = distance(UV * aspect, pip_uv * aspect);
	float hole = smoothstep(radius * 0.35, radius, d);
	for (int i = 0; i < 8; i++) {
		if (lights[i].z > 0.0) {
			float dl = distance(UV * aspect, lights[i].xy * aspect);
			hole = min(hole, smoothstep(lights[i].z * 0.3, lights[i].z, dl));
		}
	}
	float vignette = smoothstep(0.55, 1.15, distance(UV, vec2(0.5)) * 1.45) * 0.45;
	COLOR = vec4(0.0, 0.005, 0.02, clamp(darkness * hole + vignette, 0.0, 0.97));
}
"""

var stats: Dictionary
var player: Player
var terrain: Terrain
var spawner: Spawner
var site: LaunchSite
var backdrop: Backdrop
var pip: Pip
var hud: Hud
var style := StyleScore.new()
var camera: Camera2D
var tint: CanvasModulate
var whale: Whale
var walls := {}                       # wall index -> NetWall, created when the terrain reaches it
var max_depth_m := 0.0
var top_speed := 0.0
var end_reason := ""
var nets_cut := 0
var animals_freed := 0
var plastic := 0
var wall_bonus := 0
var wall_info := {}                   # filled when a wall stops the run: name, hp before/after, max
var lumen_freed := false
var walls_torn: Array[int] = []       # walls torn open on this dive: main plays their story scenes after it
var ended := false
var _tow_timer := 0.0
var _shake := 0.0
var _zone := -1
var _darkness: ColorRect
var _bubbles: CPUParticles2D
var terrain_seed := 0
var _zone_state := {}                 # trick zone id -> "armed", "failed" or "done"
var _radio_said := {}                 # radio lines already used this dive, so each plays once


func _ready() -> void:
	stats = Balance.stats_for(Game.levels)
	var layer := CanvasLayer.new()                    # everything behind the world
	layer.layer = -5
	add_child(layer)
	backdrop = Backdrop.new()
	layer.add_child(backdrop)
	tint = CanvasModulate.new()
	add_child(tint)
	terrain = Terrain.new()
	terrain_seed = randi()
	terrain.setup(terrain_seed)
	terrain.all_lit = Game.story_complete
	site = LaunchSite.new()
	site.ramp_level = stats["ramp_level"]
	add_child(site)
	add_child(terrain)
	spawner = Spawner.new()
	spawner.setup(terrain, stats, randi())
	spawner.net_touched.connect(_on_net_touched)
	spawner.pickup_touched.connect(_on_pickup_touched)
	spawner.hazard_touched.connect(_on_hazard_touched)
	add_child(spawner)
	player = Player.new()
	add_child(player)
	player.start(stats, terrain)
	player.ended.connect(_on_player_ended)
	player.launched.connect(func(): Audio.play("launch"))
	player.splashed.connect(_on_splashed)
	player.hit_floor.connect(func(into_speed: float):
		_bump(clampf(into_speed / 40.0, 3.0, 14.0))
		Audio.play("net_hit", -6.0, 0.7))
	player.hit_ceiling.connect(func():
		_bump(8.0)
		Audio.play("net_hit", -6.0, 0.7))
	pip = Pip.new()
	pip.player = player
	pip.spawner = spawner
	pip.stats = stats
	pip.position = player.position
	add_child(pip)
	_bubbles = Art.particles(26, 1.2, 5.0, 12.0, Color(Art.ICE, 0.45), false)
	_bubbles.local_coords = false
	_bubbles.gravity = Vector2(0, -90)
	_bubbles.initial_velocity_max = 25.0
	_bubbles.position = Vector2(-30, 0)
	player.add_child(_bubbles)
	camera = Camera2D.new()
	camera.position = player.position
	add_child(camera)
	camera.make_current()
	_build_overlay()
	player.landed.connect(style.landed)
	player.looped.connect(style.looped)
	player.grind_ended.connect(style.grind_ended)
	player.flipped.connect(func(): hud.show_trick("FLIP!", 0))
	style.trick.connect(func(label: String, points: int): hud.show_trick(label, points))
	terrain.update(camera.position.x)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_follow_with_camera(delta)
	var water := player.position.y > 0.0
	_bubbles.emitting = water and player.state != Player.State.DONE
	Audio.set_loop("boost_loop", player.thrusting)
	if not ended:
		style.update(delta)
		spawner.update(player)
		_check_trick_zones()
		_spawn_walls()
		_check_walls()
		_story_checks()
		_hazard_warnings()
		_zone_banner()
		max_depth_m = maxf(max_depth_m, player.position.y / Balance.PX_PER_M)
		top_speed = maxf(top_speed, player.vel.length())
		Audio.low_oxygen_alarm(player.oxygen / stats["max_oxygen"] < 0.15 and water, delta)
	else:
		_tow_timer += delta / maxf(Engine.time_scale, 0.05)
		if _tow_timer >= TOW_DELAY:
			set_process(false)
			Audio.set_loop("boost_loop", false)
			finished.emit(make_result())


# Camera leads in the direction of travel and zooms out a little when fast.
func _follow_with_camera(delta: float) -> void:
	var lead := (player.vel * 0.3).limit_length(320.0)
	camera.position = camera.position.lerp(player.position + lead, 1.0 - exp(-6.0 * delta))
	var zoom_target := lerpf(1.0, 0.7, clampf(player.vel.length() / 1100.0, 0.0, 1.0))
	camera.zoom = camera.zoom.lerp(Vector2(zoom_target, zoom_target), 1.0 - exp(-2.0 * delta))
	_shake = maxf(0.0, _shake - 40.0 * delta)
	var shake_amount := _shake if Game.settings["shake"] else 0.0
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount
	terrain.view_half = 640.0 / camera.zoom.x + 300.0
	terrain.update(camera.position.x, delta)
	site.follow(camera.position, delta)
	backdrop.follow(camera.position, camera.zoom.x, terrain.floor_y(camera.position.x), delta)
	var palette := Art.zone_palette(player.position.x)
	tint.color = palette["tint"]
	_update_darkness(palette["dark"])


func _update_darkness(amount: float) -> void:
	var screen_pos := get_viewport().get_canvas_transform() * pip.global_position
	var shader_material := _darkness.material as ShaderMaterial
	shader_material.set_shader_parameter("pip_uv", screen_pos / Vector2(1280, 720))
	shader_material.set_shader_parameter("darkness", amount)
	# Glowing creatures light up the dark around them, so a ray's warning flash is visible in the Trench.
	var lights := PackedVector3Array()
	lights.resize(8)
	var count := 0
	for hazard in spawner.hazards:
		var light := hazard.light_radius()
		var uv := get_viewport().get_canvas_transform() * hazard.global_position / Vector2(1280, 720)
		if light > 0.0 and count < 8 and uv.x > -0.2 and uv.x < 1.2 and uv.y > -0.2 and uv.y < 1.2:
			lights[count] = Vector3(uv.x, uv.y, light * camera.zoom.x)
			count += 1
	shader_material.set_shader_parameter("lights", lights)


# ---- Net walls ----

func _spawn_walls() -> void:
	if Game.endless_mode:
		return
	for i in Balance.WALLS.size():
		if walls.has(i):
			continue
		var x: float = Balance.WALLS[i]["at_m"] * Balance.PX_PER_M
		if x > terrain.points[terrain.points.size() - 1].x - 300.0:
			continue
		var wall := NetWall.new()
		wall.position = Vector2(x, 0)
		wall.setup(i, maxf(terrain.ceiling_y(x), 0.0), terrain.floor_y(x), Game.wall_broken(i))
		add_child(wall)
		walls[i] = wall
		if i == Balance.WALLS.size() - 1:
			_add_whale(x, wall)


func _add_whale(wall_x: float, wall: NetWall) -> void:
	whale = Whale.new()
	whale.position = Vector2(wall_x + 760.0, (wall.y_top + wall.y_bottom) / 2.0)
	whale.z_index = -1
	whale.lit = 1.0 if wall.torn else 0.0
	whale.wrapped = 0.0 if wall.torn else 1.0
	add_child(whale)


func _check_walls() -> void:
	for i in walls:
		var wall: NetWall = walls[i]
		if wall.torn:
			continue
		if absf(player.position.x - wall.position.x) < NetWall.HALF_WIDTH + Balance.PLAYER_RADIUS \
				and player.position.y > wall.y_top - 60.0 and player.position.y < wall.y_bottom + 60.0:
			_hit_wall(i, wall)
			return


# damage = speed * ballast * cutter. A wall that survives keeps its damage for next time.
func _hit_wall(index: int, wall: NetWall) -> void:
	var before := wall.hp
	var damage: float = player.vel.length() * stats["ballast_mult"] * stats["cutter_mult"] * Balance.WALL_DAMAGE_SCALE
	wall.hit(damage * (1000.0 if Debug.is_on("wall_kill") else 1.0))
	Game.wall_hp[str(index)] = wall.hp
	Game.save_game()
	_bump(16.0)
	if wall.torn:
		Audio.play("wall_break")
		wall_bonus += int(Balance.WALLS[index]["bonus"])
		walls_torn.append(index)
		player.vel *= Balance.WALL_SPEED_KEEP
		hud.show_caption("%s torn open!  +%d tags" % [Balance.WALLS[index]["name"], Balance.WALLS[index]["bonus"]], 3.0)
		if index == Balance.WALLS.size() - 1:
			_free_the_lumen()
	else:
		Audio.play("wall_hit")
		wall_info = {"name": Balance.WALLS[index]["name"], "before": before, "after": wall.hp, "max": wall.hp_max}
		player.finish("wall")


# Slow motion, the whale lights up, her song plays, then the run ends into the ending cards.
func _free_the_lumen() -> void:
	lumen_freed = true
	Game.story_complete = true
	Game.save_game()
	terrain.all_lit = true
	Audio.play("whale_song")
	Engine.time_scale = 0.3
	get_tree().create_timer(1.0, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
	if whale:
		create_tween().tween_property(whale, "lit", 1.0, 2.5)
		create_tween().tween_property(whale, "wrapped", 0.0, 1.5)
	get_tree().create_timer(3.5, true, false, true).timeout.connect(func(): player.finish("lumen"))


# ---- Debug helpers (called from autoload/debug.gd) ----

# Jump Nova to a distance in metres, in the middle of the corridor, moving forward.
func debug_teleport(metres: float) -> void:
	var x := metres * Balance.PX_PER_M
	if x < terrain.points[0].x + 400.0:
		terrain.setup(terrain_seed)                  # the terrain behind us was forgotten: rebuild the same trench
	terrain.update(x)
	var corridor := Balance.corridor_at(x)
	var floor_y := terrain.floor_y(x)
	var top := maxf(terrain.ceiling_y(x), 0.0)
	player.state = Player.State.WATER
	player.looping = false
	player.position = Vector2(x, clampf(floor_y - corridor * 0.5, top + 60.0, floor_y - 80.0))
	player.vel = Vector2(520, 60)
	player.angle = 0.1
	spawner.debug_reset(x - 300.0)
	camera.position = player.position
	pip.position = player.position
	style.break_chain()
	_zone_state.clear()
	_zone = -1
	_zone_banner()


func debug_spawn(kind: String) -> void:
	var pos := player.position + Vector2(600, 0)
	match kind:
		"net", "animal":
			var net := Net.new()
			net.setup(randi() % 4, kind == "animal")
			net.position = pos
			spawner.add_child(net)
			spawner.nets.append(net)
		"piranha", "puffer", "ray":
			spawner.debug_add_hazard(kind, pos)
		_:
			spawner.debug_add_pickup(kind, pos)


# ---- Trick zones: long slopes flown down without touching rock ----

func _check_trick_zones() -> void:
	var x := player.position.x
	for zone in terrain.trick_zones:
		var id: int = zone["id"]
		var state: String = _zone_state.get(id, "")
		if state == "done" or state == "failed" or x < zone["x0"] - 60.0 or x > zone["x1"] + 800.0:
			continue
		if state == "":
			# Armed at the lip, while flying (not scraping) near the zone's starting height.
			var near_lip: bool = player.position.y < zone["y0"] + 150.0
			if x >= zone["x0"] - 40.0 and near_lip and player.state == Player.State.WATER and not player.touching_rock:
				_zone_state[id] = "armed"
			continue
		if player.touching_rock:
			_zone_state[id] = "failed"
			continue
		var cleared: bool = player.position.y >= zone["y1"] - 250.0
		if cleared:
			_zone_state[id] = "done"
			style.slope_cleared(absf(zone["y1"] - zone["y0"]))
# ---- Story during the dive ----

# The first time a wall comes into view, ask main to pause and play its meeting scene.
# Radio lines never pause anything: they appear in a small box under the distance panel.
func _story_checks() -> void:
	for i in walls:
		var wall: NetWall = walls[i]
		var id := "wall%d_meet" % i
		if not wall.torn and not Game.scene_seen(id) and not _radio_said.has(id) \
				and player.position.x > wall.position.x - MEET_DISTANCE:
			_radio_said[id] = true
			story_moment.emit(id)
	if player.position.x > 1200.0 and Game.dives % 3 == 1:              # Mom calls in on every third dive
		var walls_down := 4 if Game.story_complete else Balance.WALLS.size() - _walls_standing()
		_radio_once("mom", "radio", Story.MOM_LINES[mini(walls_down, Story.MOM_LINES.size() - 1)])
	if player.oxygen / stats["max_oxygen"] < 0.25 and player.position.y > 0.0:
		_radio_once("o2", "pip", Story.LOW_O2_LINE)


func _walls_standing() -> int:
	var standing := 0
	for i in Balance.WALLS.size():
		if not Game.wall_broken(i):
			standing += 1
	return standing


func _radio_once(key: String, who: String, text: String) -> void:
	if _radio_said.has(key) or text == "":
		return
	_radio_said[key] = true
	hud.show_radio(who, text)


# ---- Results ----

func make_result() -> Dictionary:
	var distance_m := maxf(0.0, player.position.x / Balance.PX_PER_M)
	var base_tags := tags_so_far()
	var style_summary := style.summary(base_tags)
	return {
		"reason": end_reason,
		"distance_m": distance_m,
		"max_depth_m": max_depth_m,
		"top_speed": top_speed,
		"nets_cut": nets_cut,
		"animals_freed": animals_freed,
		"plastic": plastic,
		"wall_bonus": wall_bonus,
		"wall_info": wall_info,
		"lumen_freed": lumen_freed,
		"walls_torn": walls_torn,
		"fleet_cut": spawner.loose_nets_up_to(player.position.x),
		"style": style_summary,
		"style_tags": style_summary["tags"],
		"tags": base_tags + int(style_summary["tags"]),
	}


# The dive's normal tags (style bonus is added on top when the dive ends).
func tags_so_far() -> int:
	return Balance.tags_for(maxf(0.0, player.position.x / Balance.PX_PER_M), max_depth_m, nets_cut, animals_freed, wall_bonus)


func _on_net_touched(net: Net) -> void:
	net.cut_open()
	nets_cut += 1
	style.net_cut()
	player.vel *= stats["net_slow"]
	Audio.play("cut")
	if net.has_animal:
		animals_freed += 1
		player.add_oxygen(Balance.OXYGEN_FROM_ANIMAL)
		if animals_freed <= 2:
			_radio_once("animal_%d" % animals_freed, "nova", Story.ANIMAL_LINES[(Game.animals_freed_total + animals_freed) % Story.ANIMAL_LINES.size()])
		player.vel += player.vel.normalized() * Balance.ANIMAL_BURST      # thank-you speed burst
		Audio.play("pickup", -2.0, 1.3)
	_bump(6.0)
	_hit_stop(0.05)


# What each creature does to Nova (numbers in balance.gd, the creatures themselves in hazard.gd).
func _on_hazard_touched(hazard: Hazard) -> void:
	hazard.on_hit()
	if Debug.is_on("god"):
		return                                          # debug god mode: creatures cannot hurt Nova
	match hazard.kind:
		"piranha":
			if player.vel.length() > Balance.PIRANHA_OUTRUN:
				style.close_call("TOO FAST TO BITE")          # speed beats the school
				return
			player.oxygen = maxf(0.0, player.oxygen - Balance.PIRANHA_OXYGEN)
			player.vel *= Balance.PIRANHA_SLOW
			hud.show_trick("PIRANHA BITE  -%d s O2" % Balance.PIRANHA_OXYGEN, 0, true)
			Audio.play("net_hit", 0.0, 1.7)
			_bump(10.0)
		"puffer":
			var away := (player.position - hazard.position).normalized()
			player.vel = away * player.vel.length() * Balance.PUFFER_KEEP    # bounced off the spikes
			player.angle = clampf(away.angle(), Balance.ANGLE_MIN, Balance.ANGLE_MAX)
			player.oxygen = maxf(0.0, player.oxygen - Balance.PUFFER_OXYGEN)
			hud.show_trick("SPIKED!", 0, true)
			Audio.play("wall_hit", -2.0, 1.6)
			_bump(12.0)
		"ray":
			player.stun(Balance.RAY_STUN)
			player.vel *= Balance.RAY_SLOW
			player.oxygen = maxf(0.0, player.oxygen - Balance.RAY_OXYGEN)
			hud.show_trick("ZAPPED!", 0, true)
			Audio.play("alarm", -2.0, 2.2)
			_bump(14.0)
	style.break_chain()


func _hazard_warnings() -> void:
	for hazard in spawner.hazards:
		var tip := "tip_" + hazard.kind
		if not Game.scene_seen(tip) and absf(hazard.position.x - player.position.x) < 900.0:
			Game.seen_scenes.append(tip)              # saved with the slot: each warning plays once per save
			_radio_once(tip, "pip", Story.HAZARD_LINES[hazard.kind])


func _on_pickup_touched(pickup: Pickup) -> void:
	pickup.collect()
	match pickup.kind:
		"o2":
			player.add_oxygen(Balance.OXYGEN_FROM_CANISTER)
			Audio.play("o2")
		"fuel":
			player.add_fuel(Balance.FUEL_FROM_CELL)
			Audio.play("fuel")
		_:
			plastic += 1
			Audio.play("pickup", -10.0, 1.0 + 0.04 * (plastic % 8))


func _on_splashed(pos: Vector2, loss: float) -> void:
	var stage := 4 if Game.next_wall() < 0 or Game.endless_mode else Game.next_wall()
	_radio_once("start", "pip", Story.DIVE_START[stage])
	Audio.play("splash", 0.0, 1.0 - loss)
	var burst := Art.particles(40, 0.9, 6.0, 16.0, Color(Art.ICE, 0.8), true)
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.spread = 70.0
	burst.direction = Vector2.UP
	burst.initial_velocity_min = 120.0
	burst.initial_velocity_max = 380.0
	burst.gravity = Vector2(0, 700)
	burst.position = Vector2(pos.x, 0)
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(1.5).timeout.connect(burst.queue_free)
	_bump(clampf(loss * 20.0, 2.0, 8.0))


func _bump(amount: float) -> void:
	_shake = maxf(_shake, amount)


# A tiny freeze on impact makes cutting a net feel crunchy. The timer ignores time_scale.
func _hit_stop(seconds: float) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _zone_banner() -> void:
	var zone := Balance.zone_index_at(player.position.x)
	if zone != _zone:
		_zone = zone
		if player.position.x > 600.0:
			hud.show_banner(Balance.ZONES[zone]["name"], "%d m" % Balance.ZONES[zone]["start_m"])
			if zone > 0:
				_radio_once("zone_%d" % zone, "pip", Story.ZONE_LINES[zone])


func _on_player_ended(reason: String) -> void:
	ended = true
	end_reason = reason
	Audio.play("run_end")
	Audio.set_loop("boost_loop", false)
	hud.show_towing(reason)


# ---- Screen-space layers: darkness overlay and HUD ----

func _build_overlay() -> void:
	var dark_layer := CanvasLayer.new()
	dark_layer.layer = 5
	add_child(dark_layer)
	_darkness = ColorRect.new()
	_darkness.size = Vector2(1280, 720)
	_darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = DARKNESS_SHADER
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	_darkness.material = shader_material
	dark_layer.add_child(_darkness)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = Hud.new()
	hud.run = self
	hud_layer.add_child(hud)
	if Game.settings["touch"] or DisplayServer.is_touchscreen_available():
		hud_layer.add_child(TouchControls.new())
	if Game.dives < 3:
		if Game.settings["touch"] or DisplayServer.is_touchscreen_available():
			hud.show_caption("Hold the bottom half to dive for speed, the top half to glide up. BOOST for a push.", 8.0)
		else:
			hud.show_caption("D / Right: nose down, dive for speed.   A / Left: nose up, glide.   Space: boost", 7.0)
