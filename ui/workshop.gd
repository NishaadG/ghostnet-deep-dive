class_name Workshop
extends Control
# The shop between dives. Left: your rig and its stats. Right: tabs of gear tiers, tuning upgrades
# and the Port Halo programme. Bottom: the journey (net walls) and the big DIVE button.

signal dive_pressed
signal menu_pressed

const TABS := ["GEAR", "TUNING", "PORT HALO"]

var _tab := 0
var _content: Control
var _tab_buttons: Array[Button] = []
var _rig: DiverRig
var _left: Control
var _top: Control
var _journey: Control
var _mode_button: Button
var _time := 0.0


func _ready() -> void:
	size = Vector2(1280, 720)
	var scene := MenuScene.new()
	scene.dim = 0.5
	scene.show_diver = false
	add_child(scene)
	_top = _layer(_draw_top)
	_build_left()
	_build_tabs()
	_content = Control.new()
	add_child(_content)
	_journey = _layer(_draw_journey)
	_build_bottom()
	refresh()


func refresh() -> void:
	for child in _content.get_children():
		child.queue_free()
	match _tab:
		0:
			ShopRows.gear_tab(_content, refresh)
		1:
			ShopRows.tuning_tab(_content, refresh)
		_:
			ShopRows.port_halo_tab(_content, refresh)
	for i in _tab_buttons.size():
		_tab_buttons[i].disabled = i == _tab                    # the open tab looks pressed
	_rig.tiers = {"craft": Game.level("craft"), "booster": Game.level("booster"), "cutter": Game.level("cutter")}
	_mode_button.visible = Game.story_complete
	_mode_button.text = "MODE: ENDLESS" if Game.endless_mode else "MODE: STORY"
	_top.queue_redraw()
	_left.queue_redraw()
	_journey.queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_rig.position = Vector2(214, 250 + sin(_time * 1.4) * 6.0)
	_rig.rotation = sin(_time * 0.9) * 0.06
	_rig.speed = 220.0
	_rig.thrust = 0.6 if fmod(_time, 6.0) < 1.5 else 0.0     # a puff of boost now and then


# A full-size transparent control that draws with the given function.
func _layer(draw_fn: Callable) -> Control:
	var control := Control.new()
	control.size = size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.draw.connect(draw_fn.bind(control))
	add_child(control)
	return control


# ---- Left panel: rig preview and stats ----

func _build_left() -> void:
	add_child(UiKit.panel(Vector2(24, 90), Vector2(380, 520)))
	_rig = DiverRig.new()
	_rig.body_scale = 2.4
	add_child(_rig)
	_left = _layer(_draw_left)


func _draw_left(c: Control) -> void:
	var stats := Balance.stats_for(Game.levels)
	var best := Balance.stats_for(_maxed_levels())
	var bars := [
		["LAUNCH", float(stats["launch_speed"]) / float(best["launch_speed"]), Art.CYAN],
		["GLIDE", float(stats["wing_mult"]) / float(best["wing_mult"]), Art.CYAN],
		["BOOST", float(stats["thrust_mult"]) * float(stats["max_fuel"]) / (float(best["thrust_mult"]) * float(best["max_fuel"])), Art.AMBER],
		["AIR", float(stats["max_oxygen"]) / float(best["max_oxygen"]), Art.CYAN],
		["CUTTER", float(stats["cutter_mult"]) / float(best["cutter_mult"]), Art.MAGENTA],
	]
	for i in bars.size():
		var y := 360.0 + i * 34.0
		c.draw_string(Game.font, Vector2(52, y + 12), bars[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(Art.ICE, 0.8))
		c.draw_rect(Rect2(150, y, 230, 12), Color(1, 1, 1, 0.1))
		var fill := Rect2(150, y, 230.0 * clampf(bars[i][1], 0.02, 1.0), 12)
		c.draw_rect(fill, bars[i][2])
		Art.glow(c, fill.end - Vector2(0, 6), 14.0, Color(bars[i][2], 0.4))
	var names := "%s  ·  %s  ·  %s" % [Balance.owned_name("craft", Game.level("craft")),
			Balance.owned_name("booster", Game.level("booster")), Balance.owned_name("cutter", Game.level("cutter"))]
	c.draw_string(Game.font_bold, Vector2(24, 544), names, HORIZONTAL_ALIGNMENT_CENTER, 380, 15, Color(Art.ICE, 0.85))
	var line: String = Balance.HARBOUR_LINES[mini(Game.level("net_return"), Balance.HARBOUR_LINES.size() - 1)]
	c.draw_string(Game.font, Vector2(36, 580), "\"%s\"" % line, HORIZONTAL_ALIGNMENT_LEFT, 356, 12, Color(Art.AMBER, 0.8))


func _maxed_levels() -> Dictionary:
	var levels := {}
	for id in Balance.UPGRADE_ORDER:
		levels[id] = Balance.upgrade_max(id)
	return levels


# ---- Top bar ----

func _draw_top(c: Control) -> void:
	c.draw_style_box(UiKit.glass(Art.CYAN, 0.7, 0), Rect2(0, 0, 1280, 72))
	c.draw_string(Game.font_bold, Vector2(28, 46), "WORKSHOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Art.ICE)
	c.draw_string(Game.font, Vector2(210, 44), "Slot %d     Dive %d     Best %d m" % [Game.slot, Game.dives + 1, Game.best_distance], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(Art.ICE, 0.75))
	c.draw_style_box(UiKit.glass(Art.AMBER, 0.6, 22), Rect2(1060, 14, 190, 44))
	c.draw_colored_polygon(PackedVector2Array([Vector2(1084, 28), Vector2(1100, 28), Vector2(1110, 36), Vector2(1100, 44), Vector2(1084, 44)]), Art.AMBER)
	c.draw_circle(Vector2(1100, 36), 2.5, Art.INK)
	c.draw_string(Game.font_bold, Vector2(1120, 46), "%d" % Game.tags, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Art.AMBER)
	# Reef lights: one dot per freed animal (up to ten), in the coral colours.
	c.draw_string(Game.font, Vector2(700, 28), "REEF LIGHTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Art.ICE, 0.7))
	for i in 10:
		var centre := Vector2(708 + i * 30.0, 46)
		if i < mini(Game.reef_lights(), 10):
			var color: Color = DecorArt.CORAL_COLORS[i % DecorArt.CORAL_COLORS.size()]
			Art.glow(c, centre, 20.0, Color(color, 0.5))
			c.draw_circle(centre, 8.0, color)
		else:
			c.draw_arc(centre, 7.0, 0.0, TAU, 16, Color(1, 1, 1, 0.3), 2.0, true)


# ---- Tabs and bottom row ----

func _build_tabs() -> void:
	for i in TABS.size():
		var button := UiKit.button(TABS[i], Vector2(190, 44), Art.AMBER if i == 2 else Art.CYAN, false, 18)
		button.position = Vector2(424 + i * 202, 92)
		var accent := Art.AMBER if i == 2 else Art.CYAN
		button.add_theme_stylebox_override("disabled", UiKit.button_style(Color(accent, 0.9), accent.lightened(0.3)))   # the open tab is filled
		button.add_theme_color_override("font_disabled_color", Art.INK)
		button.pressed.connect(func():
			_tab = i
			refresh())
		add_child(button)
		_tab_buttons.append(button)


func _build_bottom() -> void:
	var dive := UiKit.button("DIVE", Vector2(260, 84), Art.CYAN, true, 44)
	dive.position = Vector2(996, 612)
	dive.pressed.connect(func(): dive_pressed.emit())
	add_child(dive)
	_mode_button = UiKit.button("", Vector2(260, 34), Art.MAGENTA, false, 15)
	_mode_button.position = Vector2(996, 572)
	_mode_button.pressed.connect(func():
		Game.endless_mode = not Game.endless_mode
		Game.save_game()
		refresh())
	add_child(_mode_button)
	var menu := UiKit.button("MENU", Vector2(120, 40), Art.CYAN, false, 16)
	menu.position = Vector2(24, 628)
	menu.pressed.connect(func(): menu_pressed.emit())
	add_child(menu)


# The four net walls and how much of each is left.
func _draw_journey(c: Control) -> void:
	c.draw_style_box(UiKit.glass(Art.MAGENTA, 0.55), Rect2(424, 580, 556, 116))
	c.draw_string(Game.font_bold, Vector2(440, 604), "THE JOURNEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Art.MAGENTA)
	for i in Balance.WALLS.size():
		var x := 440.0 + i * 134.0
		var remaining: float = Game.wall_remaining(i) / float(Balance.WALLS[i]["hp"])
		var done := Game.wall_broken(i)
		c.draw_string(Game.font_bold, Vector2(x, 630), String(Balance.WALLS[i]["name"]), HORIZONTAL_ALIGNMENT_LEFT, 128, 13, Art.AMBER if done else Art.ICE)
		c.draw_string(Game.font, Vector2(x, 648), "%d m" % Balance.WALLS[i]["at_m"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Art.ICE, 0.6))
		c.draw_rect(Rect2(x, 660, 120, 10), Color(1, 1, 1, 0.1))
		if done:
			c.draw_rect(Rect2(x, 660, 120, 10), Art.AMBER)
			c.draw_string(Game.font_bold, Vector2(x, 686), "TORN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Art.AMBER)
		else:
			c.draw_rect(Rect2(x, 660, 120.0 * remaining, 10), Art.MAGENTA)
			c.draw_string(Game.font, Vector2(x, 686), "%d%% left" % int(remaining * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Art.ICE, 0.7))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm"):
		dive_pressed.emit()
	elif event.is_action_pressed("pause"):
		menu_pressed.emit()
