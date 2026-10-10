class_name CutsceneStage
extends Node2D
# The picture behind a cutscene. A "set" is one place (the dock, the reef, a net wall, the Abyss);
# switching sets throws the old nodes away and builds the new ones. Actions (`act`) are the small
# animations a beat can ask for: Nova swims in, a net is cut, the reef lights go out, the Lumen is freed.
# Everything reuses the game's own drawn-in-code pieces (DiverRig, Pip, Net, NetWall, Whale, LaunchSite)
# so the cutscenes look exactly like the dive.

# Every set and action a beat in Story may name (tests/cutscenes.gd checks the story against these).
const SETS := ["dock", "dock_harbour", "dock_all", "dock_family", "night_dock", "under_boat", "reef", "reef_dark",
		"gate", "gate_torn", "city", "city_torn", "slope", "slope_torn", "drift", "abyss",
		"tag_11", "tag_scratched", "tag_07", "sign", "signal"]
const ACTIONS := ["shake", "flash", "radio", "snip", "net_sink", "nova_in", "nova_cut", "cut_sparks", "whale_pass",
		"lights_out", "lights_on", "pip_alarm", "faint_song", "whale_free", "fish_burst", "thud"]

# The camera looks at `cam_pos` (world px) with `cam_zoom`. World px equal screen px at zoom 1.
var cam_pos := Vector2(640, 360)
var cam_zoom := 1.0
var set_name := ""
var actors := {}               # "nova", "pip", "captain", "whale", "wall", "net"... -> Node2D
var coral_lit := 1.0           # 0..1: how many of the reef's corals glow (the Lumen's song keeps them lit)
var dark := 0.0                # 0..1: deep-water darkness with a pool of light around Pip
var flash := 0.0
var shake := 0.0
var time := 0.0

var _backdrop: Backdrop        # screen-space water, ridges and plankton, as in the dive
var _backdrop_at := Vector2.ZERO
var _world: Node2D             # everything the camera moves
var _darkness: ColorRect
var _front: Node2D             # flash and radio static, drawn on top of everything
var _radio := 0.0
var _rope := true              # the line from Boat 07 to its net, until it is cut
var _pile_drop := 0.0          # dock: the pile of nets Nova brings up, 0 = in the air, 1 = landed
var _tweens: Array[Tween] = [] # tweens on the stage itself; a set change stops them


func _ready() -> void:
	_backdrop = Backdrop.new()
	add_child(_backdrop)
	_world = Node2D.new()
	add_child(_world)
	_darkness = ColorRect.new()
	_darkness.size = Vector2(1280, 720)
	_darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = Run.DARKNESS_SHADER               # the same light-around-Pip shader as the dive
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	_darkness.material = shader_material
	add_child(_darkness)
	_front = Node2D.new()
	_front.draw.connect(_draw_front)
	add_child(_front)


func _process(delta: float) -> void:
	time += delta
	flash = maxf(0.0, flash - delta * 2.2)
	shake = maxf(0.0, shake - delta * 30.0)
	_radio = maxf(0.0, _radio - delta)
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	_world.scale = Vector2(cam_zoom, cam_zoom)
	_world.position = Vector2(640, 360) - cam_pos * cam_zoom
	_backdrop.follow(_backdrop_at, 1.0, _backdrop_at.y + 700.0, delta)
	_follow_pip(delta)
	if actors.has("site"):
		(actors["site"] as LaunchSite).follow(Vector2(-911, 0), delta)
	var shader_material := _darkness.material as ShaderMaterial
	shader_material.set_shader_parameter("darkness", dark)
	if actors.has("pip"):
		var pip_screen: Vector2 = _world.get_global_transform() * (actors["pip"] as Node2D).position
		shader_material.set_shader_parameter("pip_uv", pip_screen / Vector2(1280, 720))
	for child in _world.get_children():
		child.queue_redraw()
	_front.queue_redraw()


# Pip trails Nova the way it does in the dive: a lerp toward a spot above and behind her, with a bob.
func _follow_pip(delta: float) -> void:
	if not (actors.has("pip") and actors.has("nova")):
		return
	var pip: Node2D = actors["pip"]
	var nova: Node2D = actors["nova"]
	if not (nova is DiverRig):
		return
	var target := nova.position + Vector2(-80, -60) + Vector2(0, sin(time * 2.5) * 8.0)
	pip.position = pip.position.lerp(target, 1.0 - exp(-5.0 * delta))


# A tween on the stage that dies when the set changes, so a camera move or a fade from the
# previous set can never leak into the next one.
func _tween() -> Tween:
	var tween := create_tween()
	_tweens.append(tween)
	return tween


func camera_to(target: Vector2, zoom: float, seconds: float) -> void:
	var tween := _tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "cam_pos", target, seconds)
	tween.tween_property(self, "cam_zoom", zoom, seconds)


# The character who is talking glows and bobs (only standing figures do this).
func set_speaker(who: String) -> void:
	for key in actors:
		if actors[key] is Figure:
			(actors[key] as Figure).speaking = key == who


# ---- Sets ----

func show_set(new_set: String) -> void:
	set_name = new_set
	for child in _world.get_children():
		_world.remove_child(child)          # out of the tree now, so the old set never draws again
		child.queue_free()
	actors.clear()
	for tween in _tweens:
		tween.kill()
	_tweens.clear()
	cam_pos = Vector2(640, 360)
	cam_zoom = 1.0
	coral_lit = 1.0
	dark = 0.0
	_rope = true
	_pile_drop = 1.0
	_backdrop.visible = true
	_layer(_draw_back)                                     # drawn first: water, seabed, scenery
	match new_set:
		"dock", "dock_harbour", "dock_all", "dock_family", "night_dock":
			_build_dock(new_set)
		"under_boat":
			_backdrop_at = Vector2(1000, 120)
			_add_net("net", Vector2(900, 420), 1, false)
			_layer(_draw_hull)
		"reef", "reef_dark":
			_backdrop_at = Vector2(1000, 500)
			coral_lit = 0.0 if new_set == "reef_dark" else 1.0
			_add_nova(Vector2(-160, 400) if new_set == "reef" else Vector2(470, 380))
			if new_set == "reef":
				_add_net("net", Vector2(840, 360), 1, true)
		"gate", "gate_torn":
			_backdrop_at = Vector2(3800, 700)
			_add_wall(0, new_set == "gate_torn")
			_add_nova(Vector2(330, 390))
		"city", "city_torn":
			_backdrop_at = Vector2(14000, 1600)
			_add_wall(1, new_set == "city_torn")
			_add_nova(Vector2(330, 400))
		"slope", "slope_torn":
			_backdrop_at = Vector2(27500, 4200)
			dark = 0.55
			_add_wall(2, new_set == "slope_torn")
			_add_nova(Vector2(330, 400))
		"drift":
			_backdrop_at = Vector2(30000, 6000)
			dark = 0.45
			for i in 9:
				var net := _add_net("drift_%d" % i, Vector2(80 + i * 140, 140 + Art.hash01(i) * 380), 3, false)
				net.scale = Vector2.ONE * (0.4 + 0.3 * Art.hash01(i + 3))
			_add_nova(Vector2(620, 470))
		"abyss":
			_backdrop_at = Vector2(37000, 9000)
			dark = 0.15
			var whale := Whale.new()
			whale.position = Vector2(740, 290)
			whale.scale = Vector2(0.45, 0.45)
			whale.lit = 0.18                      # barely breathing: the faintest glow is left
			whale.wrapped = 1.0
			_world.add_child(whale)
			actors["whale"] = whale
			_add_nova(Vector2(260, 400))
		"tag_11", "tag_scratched", "tag_07", "sign", "signal":
			_backdrop.visible = false
			if new_set == "signal":
				var pip := Pip.new()
				pip.position = Vector2(400, 330)
				pip.scale = Vector2(4.5, 4.5)
				pip.alarm = true
				_world.add_child(pip)
				_layer(_draw_signal)
			else:
				_layer(_draw_closeup)


# A Node2D in the world that draws with `painter` every frame.
func _layer(painter: Callable) -> Node2D:
	var node := Node2D.new()
	node.draw.connect(painter.bind(node))
	_world.add_child(node)
	return node


func _add_nova(at: Vector2) -> void:
	var nova := DiverRig.new()
	nova.tiers = {"craft": Game.level("craft"), "booster": Game.level("booster"), "cutter": Game.level("cutter")}
	nova.speed = 200.0
	nova.body_scale = 2.0
	nova.position = at
	_world.add_child(nova)
	actors["nova"] = nova
	var pip := Pip.new()
	pip.position = at + Vector2(-80, -60)
	pip.scale = Vector2(1.4, 1.4)
	_world.add_child(pip)
	actors["pip"] = pip


func _add_net(key: String, at: Vector2, kind: int, with_animal: bool) -> Net:
	var net := Net.new()
	net.setup(kind, with_animal)
	net.position = at
	_world.add_child(net)
	actors[key] = net
	return net


func _add_wall(index: int, torn: bool) -> void:
	var wall := NetWall.new()
	wall.position = Vector2(820, 0)
	wall.setup(index, -60.0, 660.0, torn)
	wall.torn = torn                      # the scene decides, whatever this save's HP says
	wall.show_bar = false
	wall.scale = Vector2(1.3, 1.0)
	_world.add_child(wall)
	actors["wall"] = wall
	if not torn:                          # a few fish caught in the mesh
		for i in 4:
			var fish := Animal.new()
			fish.setup("fish", 1.6)
			fish.position = Vector2(820 + (Art.hash01(i) - 0.5) * 120.0, 120 + i * 120.0)
			_world.add_child(fish)


func _add_figure(key: String, kind: String, x: float, facing: float) -> void:
	var figure := Figure.new()
	figure.kind = kind
	figure.facing = facing
	figure.position = Vector2(x, 297)
	figure.scale = Vector2(0.75, 0.75)
	_world.add_child(figure)
	actors[key] = figure


# Port Halo: the game's own LaunchSite (sky, far city, Boat 07) scaled up so the deck fills the frame.
func _build_dock(variant: String) -> void:
	_backdrop.visible = false
	var site := LaunchSite.new()
	site.position = Vector2(1180, 520)
	site.scale = Vector2(1.5, 1.5)
	if variant == "night_dock":
		site.modulate = Color(0.42, 0.48, 0.85)
	_world.add_child(site)
	actors["site"] = site
	match variant:
		"dock":
			_add_figure("ilo", "ilo", 230, 1.0)
			_add_figure("captain", "captain", 560, -1.0)
			_add_figure("nova", "nova", 900, -1.0)
		"dock_harbour":
			_add_figure("harbour", "harbour", 520, 1.0)
			_add_figure("nova", "nova", 780, -1.0)
		"dock_all":
			_add_figure("captain", "captain", 380, 1.0)
			_add_figure("harbour", "harbour", 640, -1.0)
			_add_figure("nova", "nova", 880, -1.0)
		"night_dock":
			_add_figure("captain", "captain", 480, 1.0)
			_add_figure("nova", "nova", 760, -1.0)
		"dock_family":
			_add_figure("nova", "nova", 330, 1.0)
			_layer(_draw_pile)
			_add_figure("captain", "captain", 680, -1.0)
			_add_figure("ilo", "ilo", 930, -1.0)
	if actors.has("nova"):
		var pip := Pip.new()
		pip.position = (actors["nova"] as Node2D).position + Vector2(-70, -190)
		pip.scale = Vector2(1.2, 1.2)
		_world.add_child(pip)
		actors["pip_dock"] = pip


# ---- Actions ----

func act(action: String) -> void:
	match action:
		"shake":
			shake = 14.0
		"flash":
			flash = 1.0
		"radio":
			_radio = 0.7
		"snip":
			_rope = false
			flash = 0.6
			_sparks(Vector2(900, 250))
		"net_sink":
			var net: Node2D = actors.get("net")
			if net:
				var tween := _tween().set_parallel(true)
				tween.tween_property(net, "position", Vector2(980, 640), 6.0).set_ease(Tween.EASE_OUT)
				tween.tween_property(net, "rotation", 0.3, 6.0)
		"nova_in":
			_tween_actor("nova", Vector2(520, 380), 2.2)
		"nova_cut":
			_tween_actor("nova", Vector2(690, 372), 0.5)
			get_tree().create_timer(0.45).timeout.connect(_cut_net)
		"cut_sparks":
			_sparks(Vector2(470, 330) + Vector2(randf_range(-40, 40), randf_range(-30, 30)))
			flash = 0.5
			shake = 8.0
			_tween_actor("nova", Vector2(360, 420), 0.3)
		"whale_pass":
			var whale := Whale.new()
			whale.position = Vector2(1700, 170)
			whale.scale = Vector2(0.35, 0.35)
			whale.lit = 1.0
			whale.modulate = Color(1, 1, 1, 0.85)
			_world.add_child(whale)
			_world.move_child(whale, 1)                     # behind the seabed's corals, it is far away
			actors["far_whale"] = whale
			_tween().tween_property(whale, "position:x", -600.0, 16.0)
		"lights_out":
			_tween().tween_property(self, "coral_lit", 0.0, 2.5)
			var whale: Whale = actors.get("far_whale")
			if whale:
				_tween().tween_property(whale, "lit", 0.0, 2.0)
		"lights_on":
			_tween().tween_property(self, "coral_lit", 1.0, 3.0)
		"pip_alarm":
			for key in ["pip", "pip_dock"]:
				if actors.has(key):
					(actors[key] as Pip).alarm = true
		"faint_song":
			Audio.play("whale_song", -16.0, 0.8)
		"whale_free":
			var whale: Whale = actors.get("whale")
			if whale:
				_tween().tween_property(whale, "wrapped", 0.0, 1.6)
				_tween().tween_property(whale, "lit", 1.0, 3.0)
			_tween().tween_property(self, "dark", 0.0, 3.0)
			flash = 1.0
			for key in ["pip"]:
				if actors.has(key):
					(actors[key] as Pip).alarm = false
		"fish_burst":
			for i in 16:
				var fish := Animal.new()
				fish.setup("fish", 1.4 + Art.hash01(i) * 0.6)
				fish.position = Vector2(780 + randf_range(-40, 40), 120 + randf() * 420)
				fish.trapped = false
				_world.add_child(fish)
				# Bound to the fish itself, so the timer is dropped if the set changes first.
				get_tree().create_timer(i * 0.08).timeout.connect(fish.free_swim.bind(Vector2(randf_range(500, 800), randf_range(-260, 120))))
		"thud":
			_pile_drop = 0.0
			_tween().tween_property(self, "_pile_drop", 1.0, 0.35).set_ease(Tween.EASE_IN)
			get_tree().create_timer(0.35).timeout.connect(act.bind("shake"))
		_:
			push_warning("Cutscene: unknown action '%s'" % action)


func _cut_net() -> void:
	var net: Variant = actors.get("net")              # untyped: the net may already be freed
	if is_instance_valid(net) and not (net as Net).is_cut:
		(net as Net).cut_open()
		flash = 0.4


func _tween_actor(key: String, to: Vector2, seconds: float) -> void:
	var node: Node2D = actors.get(key)
	if node:
		_tween().tween_property(node, "position", to, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _sparks(at: Vector2) -> void:
	var sparks := Art.particles(30, 0.6, 3.0, 9.0, Color(Art.CYAN.lightened(0.5), 0.95), true)
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.spread = 180.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 140.0
	sparks.initial_velocity_max = 380.0
	sparks.position = at
	_world.add_child(sparks)
	sparks.emitting = true


# ---- Drawing ----

func _draw_back(ci: Node2D) -> void:
	match set_name:
		"dock", "dock_harbour", "dock_all", "dock_family", "night_dock":
			Art.gradient_rect(ci, Rect2(-600, 520, 2500, 700), Color("0d3550"), Color("02101c"))
		"under_boat":
			Art.gradient_rect(ci, Rect2(-600, -400, 2500, 510), Color("3a1b5e"), Color("ff9a6a"))
		"reef", "reef_dark":
			_seabed(ci, Color("0b2d44"), Art.CYAN, true)
		"gate", "gate_torn":
			_arch(ci)
			_seabed(ci, Color("0b2d44"), Color("ff5fa8"), true)
		"city", "city_torn":
			for i in 7:
				var x := -120.0 + i * 220.0 + Art.hash01(i) * 60.0
				DecorArt.tower(ci, Vector2(x, 140.0 + Art.hash01(i + 7) * 220.0), 150.0, 700.0, i * 9 + 3, Color("0e2744"), Color("ff5fa8"))
			_seabed(ci, Color("0e2744"), Color("ff5fa8"), false)
		"slope", "slope_torn", "drift":
			_ceiling(ci, Color("0b1a38"), Color("7a8cff"))
			_seabed(ci, Color("0b1a38"), Color("7a8cff"), false)
			for i in 6:
				DecorArt.spikes(ci, Vector2(60 + i * 230, 650), 90.0, i + 4, Color("0b1a38"), Color("7a8cff"), true)
		"abyss":
			_seabed(ci, Color("050a18"), Color("b66bff"), false)
			for i in 5:
				DecorArt.crystals(ci, Vector2(100 + i * 280, 650), 80.0, i + 11, Color("b66bff"), true, time)
		"tag_11", "tag_scratched", "tag_07", "sign", "signal":
			Art.gradient_rect(ci, Rect2(-600, -400, 2500, 1600), Color("0a1a33"), Color("010409"))


func _seabed(ci: Node2D, rock: Color, edge: Color, corals: bool) -> void:
	var line := PackedVector2Array()
	for i in 34:
		line.append(Vector2(-400 + i * 70.0, 640.0 + sin(i * 0.55) * 24.0 + sin(i * 1.3) * 8.0))
	var poly := line.duplicate()
	poly.append(Vector2(2000, 1400))
	poly.append(Vector2(-400, 1400))
	ci.draw_colored_polygon(poly, rock)
	ci.draw_polyline(line, Color(edge, 0.7), 2.5, true)
	if not corals:
		return
	var count := 12
	for i in count:
		var x := -40.0 + i * 120.0 + Art.hash01(i) * 50.0
		var lit := (i + 0.5) / count <= coral_lit
		DecorArt.coral(ci, Vector2(x, 652.0 + sin(x * 0.01) * 12.0), 90.0 + 70.0 * Art.hash01(i + 9), i * 13 + 5, i, lit, time)


func _ceiling(ci: Node2D, rock: Color, edge: Color) -> void:
	var line := PackedVector2Array()
	for i in 34:
		line.append(Vector2(-400 + i * 70.0, 40.0 + sin(i * 0.7) * 30.0))
	var poly := line.duplicate()
	poly.append(Vector2(2000, -800))
	poly.append(Vector2(-400, -800))
	ci.draw_colored_polygon(poly, rock)
	ci.draw_polyline(line, Color(edge, 0.6), 2.5, true)
	for i in 6:
		DecorArt.spikes(ci, Vector2(120 + i * 230, 50), 80.0, i + 21, rock, edge, false)


# The old harbour arch that the Reef Gate's nets piled up against.
func _arch(ci: Node2D) -> void:
	var stone := Color("123a52")
	var outline := Color(Art.CYAN, 0.35)
	for x in [640.0, 1000.0]:
		Art.shape(ci, PackedVector2Array([Vector2(x - 40, 700), Vector2(x - 30, 70), Vector2(x + 30, 70), Vector2(x + 40, 700)]), stone, outline, 2.0)
	var arc := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		arc.append(Vector2(820, 110) + Vector2(cos(a) * 210.0, sin(a) * 120.0))
	ci.draw_polyline(arc, stone, 40.0, true)
	ci.draw_polyline(arc, outline, 2.0, true)


# Under Boat 07: the hull from below, the surface line, and the rope down to its net.
func _draw_hull(ci: Node2D) -> void:
	var line := PackedVector2Array()
	for i in 40:
		var x := -200.0 + i * 50.0
		line.append(Vector2(x, 110.0 + sin(x * 0.012 + time * 1.6) * 5.0))
	ci.draw_polyline(line, Color(1, 0.9, 0.85, 0.3), 10.0, true)
	ci.draw_polyline(line, Color(1, 0.95, 0.9, 0.9), 2.5, true)
	var bob := sin(time * 1.2) * 4.0                                   # the hull sits on the right, clear of the caption
	var hull := PackedVector2Array([Vector2(760, 30 + bob), Vector2(1400, 30 + bob), Vector2(1400, 210 + bob), Vector2(860, 210 + bob)])
	Art.shape(ci, hull, Color("0f1a3a"), Color("3a5a9c"), 3.0)
	ci.draw_line(Vector2(790, 90 + bob), Vector2(1400, 90 + bob), Art.AMBER, 5.0, true)
	ci.draw_string(Game.font_bold, Vector2(1040, 180 + bob), "07", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color(Art.ICE, 0.85))
	if _rope:
		var net: Node2D = actors.get("net")
		if net:
			ci.draw_line(Vector2(900, 210 + bob), net.position + Vector2(0, -120), Color(Art.NET_COLOR, 0.8), 2.0, true)


# Dock: the pile of nets with orange fleet tags that Nova drops at her mother's feet.
func _draw_pile(ci: Node2D) -> void:
	var base := Vector2(520, 297 - (1.0 - _pile_drop) * 300.0)
	var mound := PackedVector2Array()
	for i in 15:
		var a := PI + PI * i / 14.0
		mound.append(base + Vector2(cos(a) * 110.0, sin(a) * 55.0))
	Art.shape(ci, mound, Color("2a3a52"), Art.NET_COLOR, 2.0)
	for k in 7:
		ci.draw_line(base + Vector2(-100 + k * 30, 0), base + Vector2(-60 + k * 22, -50), Color(Art.NET_COLOR, 0.6), 1.5, true)
	for k in 6:
		var p := base + Vector2(-80 + k * 32, -18 - 22 * Art.hash01(k))
		var tag := PackedVector2Array([p + Vector2(-9, -6), p + Vector2(5, -6), p + Vector2(11, 0), p + Vector2(5, 6), p + Vector2(-9, 6)])
		ci.draw_colored_polygon(tag, Color("ff7a2a"))


# Close-ups: a fleet tag held up against the net, or the old reserve sign behind the City Seal.
func _draw_closeup(ci: Node2D) -> void:
	for k in 30:                                                     # the net behind, huge and close
		var x := -400.0 + k * 90.0
		ci.draw_line(Vector2(x, -100), Vector2(x + 900, 820), Color(Art.NET_COLOR, 0.18), 3.0, true)
		ci.draw_line(Vector2(x + 900, -100), Vector2(x, 820), Color(Art.NET_COLOR, 0.18), 3.0, true)
	if set_name == "sign":
		_draw_sign(ci)
		return
	var lines := {"tag_11": ["BOAT 11", "CAPT. ORLA"], "tag_scratched": ["BOAT 0", ""], "tag_07": ["BOAT 07", "CAPT. VALE"]}
	var text: Array = lines[set_name]
	var centre := Vector2(640, 300)
	ci.draw_line(centre + Vector2(-210, -30), Vector2(470, -40), Color(Art.ICE, 0.7), 3.0, true)      # the cord it hangs from
	ci.draw_set_transform(centre, -0.12 + sin(time * 0.8) * 0.02, Vector2.ONE)
	Art.glow(ci, Vector2.ZERO, 360.0, Color("ff7a2a", 0.25))
	var card := PackedVector2Array([Vector2(-250, -120), Vector2(200, -120), Vector2(260, 0), Vector2(200, 120), Vector2(-250, 120)])
	Art.shape(ci, card, Color("ff7a2a"), Art.INK, 5.0)
	ci.draw_circle(Vector2(-210, -40), 14.0, Art.INK)
	ci.draw_string(Game.font_bold, Vector2(-180, -60), "PORT HALO FLEET", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Art.INK)
	ci.draw_string(Game.font_bold, Vector2(-200, 40), String(text[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 92, Art.INK)
	ci.draw_string(Game.font_bold, Vector2(-100, 96), String(text[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Art.INK)
	if set_name == "tag_scratched":                                   # the second digit and the name are scraped away
		for k in 9:
			ci.draw_line(Vector2(70 + k * 9, -40), Vector2(40 + k * 12, 50), Color("ffc29a"), 4.0, true)
			ci.draw_line(Vector2(-110 + k * 22, 70), Vector2(-90 + k * 22, 100), Color("ffc29a"), 4.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Art.capsule(ci, Vector2(120, 760), Vector2(400, 440), 30.0, Art.INK)        # Nova's arm reaching in to the tag
	Art.capsule(ci, Vector2(120, 760), Vector2(400, 440), 26.0, DiverRig.SUIT)
	_draw_glove(ci, Vector2(415, 422))


# Nova's orange glove, thumb up, pinching the tag.
func _draw_glove(ci: Node2D, at: Vector2) -> void:
	Art.capsule(ci, at + Vector2(-6, 10), at + Vector2(26, -8), 20.0, Art.INK)
	Art.capsule(ci, at + Vector2(-6, 10), at + Vector2(26, -8), 17.0, Color("ff7a2a"))
	Art.capsule(ci, at + Vector2(4, -6), at + Vector2(14, -34), 9.0, Art.INK)
	Art.capsule(ci, at + Vector2(4, -6), at + Vector2(14, -34), 7.0, Color("ff9a4a"))


func _draw_sign(ci: Node2D) -> void:
	var rect := Rect2(300, 130, 680, 330)
	ci.draw_line(Vector2(560, 460), Vector2(560, 720), Color("33465c"), 22.0, true)        # posts
	ci.draw_line(Vector2(720, 460), Vector2(720, 720), Color("33465c"), 22.0, true)
	ci.draw_rect(rect.grow(8), Art.INK)
	Art.gradient_rect(ci, rect, Color("2c6f6a"), Color("1a3f44"))
	ci.draw_rect(rect, Color(Art.CYAN, 0.6), false, 3.0)
	ci.draw_string(Game.font_bold, rect.position + Vector2(0, 90), "HALO MARINE RESERVE", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 46, Art.ICE)
	ci.draw_line(rect.position + Vector2(80, 120), rect.position + Vector2(600, 120), Color(Art.ICE, 0.5), 2.0, true)
	ci.draw_string(Game.font_bold, rect.position + Vector2(0, 190), "NO NETS BEYOND THIS POINT", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 36, Art.AMBER)
	ci.draw_string(Game.font, rect.position + Vector2(0, 260), "Protected reef  ·  est. 2128", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 24, Color(Art.ICE, 0.8))
	for i in 6:                                                            # coral and rust creeping over it
		DecorArt.coral(ci, Vector2(320 + i * 130, 470), 60.0 + 30.0 * Art.hash01(i), i * 7 + 2, i, i % 2 == 0, time)
		var edge := Vector2(Art.hash01(i + 30) * rect.size.x, 6.0 if i % 2 == 0 else rect.size.y - 6.0)
		ci.draw_circle(rect.position + edge, 6.0 + 8.0 * Art.hash01(i), Color("7a4a2a", 0.55))      # rust along the edges


# Pip's screen: the Lumen's song as a wave that goes flat.
func _draw_signal(ci: Node2D) -> void:
	var panel := Rect2(660, 170, 520, 320)
	ci.draw_style_box(UiKit.glass(Art.CYAN, 0.85), panel)
	ci.draw_string(Game.font_bold, panel.position + Vector2(28, 48), "LUMEN SONG", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Art.CYAN)
	var wave := PackedVector2Array()
	for i in 60:
		var x := panel.position.x + 30 + i * 4.0
		var fade := clampf(1.0 - i / 55.0, 0.0, 1.0)
		wave.append(Vector2(x, panel.position.y + 150 + sin(i * 0.6 + time * 6.0) * 50.0 * fade))
	ci.draw_polyline(wave, Art.CYAN, 3.0, true)
	var x0 := panel.position.x + 280
	while x0 < panel.end.x - 30:
		ci.draw_line(Vector2(x0, panel.position.y + 150), Vector2(x0 + 12, panel.position.y + 150), Color("ff4a4a"), 3.0, true)
		x0 += 22.0
	var blink := 0.6 + 0.4 * sin(time * 6.0)
	ci.draw_string(Game.font_bold, panel.position + Vector2(28, 270), "SIGNAL LOST", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color("ff4a4a", blink))


func _draw_front() -> void:
	if flash > 0.0:
		_front.draw_rect(Rect2(-20, -20, 1320, 760), Color(1, 1, 1, flash * 0.6))
	if _radio > 0.0:                                                      # radio static: a few bright scanlines
		for i in 14:
			var y := fposmod(Art.hash01(i) * 720.0 + time * 900.0, 720.0)
			_front.draw_line(Vector2(0, y), Vector2(1280, y), Color(Art.AMBER, 0.25 * _radio), 2.0)
