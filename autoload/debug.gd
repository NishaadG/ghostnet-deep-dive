extends Node
# Developer tools: cheats, teleporting and jump-to-anything. Open the panel with F9 (or the ` key).
# Everything the panel does goes through this file, so it is easy to read, test, and switch off:
# set ENABLED to false for a build that must not have cheats.
# `active` is the switch between DEBUG mode and the REAL game (title screen button, remembered in
# settings, or launch with `-- debug` / `-- real`). In the real game F9, the F1-F5 keys and every cheat are off.
# Autoload name: Debug.

const ENABLED := true

# Metre marks to teleport to (just before each wall, and the start of each zone).
const TELEPORTS := [
	["Start", 0], ["Reef Gate", 380], ["City", 420], ["City Seal", 1480],
	["Slope", 1520], ["Slope Curtain", 2780], ["Trench", 2820], ["Lumen's Net", 3580], ["Abyss", 3620],
]

var main: Node                      # set by main.gd, so we can read the current screen
var cheats := {"god": false, "oxygen": false, "fuel": false, "wall_kill": false, "no_creatures": false}
var active := true                  # DEBUG mode (true) or the REAL game (false)
var _panel: Node
var _badge: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	active = ENABLED and bool(Game.settings["debug_mode"])        # Game loads settings first (autoload order)
	for arg in OS.get_cmdline_user_args():
		if arg == "debug":
			active = ENABLED
		elif arg == "real":
			active = false
	_build_badge()


func is_on(cheat: String) -> bool:
	return ENABLED and active and cheats.get(cheat, false)


# Switch between DEBUG mode and the REAL game. Turning debug off also clears every cheat.
func set_active(on: bool) -> void:
	active = ENABLED and on
	if not active:
		for cheat in cheats:
			cheats[cheat] = false
		if _panel and is_instance_valid(_panel):
			_panel.queue_free()
			_panel = null
	_badge.visible = active
	Game.settings["debug_mode"] = active
	Game.save_settings()


# A small tag in the bottom-right corner, so it is always clear which mode is running.
func _build_badge() -> void:
	_badge = CanvasLayer.new()
	_badge.layer = 250
	var label := UiKit.label("DEBUG MODE   F9 = panel", 13, true, Color(Art.MAGENTA.lightened(0.3), 0.85))
	label.position = Vector2(1040, 696)
	label.size = Vector2(220, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_child(label)
	_badge.visible = active
	add_child(_badge)


func toggle_cheat(cheat: String) -> void:
	cheats[cheat] = not cheats[cheat]


func toggle_panel() -> void:
	if not (ENABLED and active):
		return
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
		_panel = null
		return
	var layer := CanvasLayer.new()
	layer.layer = 300
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(DebugPanel.new())
	get_tree().root.add_child.call_deferred(layer)        # deferred: safe even while a scene is still being set up
	_panel = layer


# The dive that is running right now, or null on any other screen.
func run() -> Run:
	if main and main._screen is Run:
		return main._screen
	return null


func screen_name() -> String:
	if main == null or main._screen == null:
		return "none"
	return String(main._screen.get_script().get_global_name())


# ---- Actions used by the panel ----

func teleport(metres: float) -> void:
	var r := run()
	if r:
		r.debug_teleport(metres)


# Jump a bit before the next canyon or drop in front of Nova.
func teleport_to_next_zone(kind: String) -> void:
	var r := run()
	if r == null:
		return
	for zone in r.terrain.trick_zones:
		if zone["kind"] == kind and zone["x0"] > r.player.position.x + 600.0:
			r.debug_teleport((zone["x0"] - 250.0) / Balance.PX_PER_M)
			return


func teleport_to_next_wall() -> void:
	var r := run()
	if r == null:
		return
	for wall in Balance.WALLS:
		var x: float = wall["at_m"] * Balance.PX_PER_M
		if x > r.player.position.x + 300.0:
			r.debug_teleport(float(wall["at_m"]) - 25.0)
			return


func fill_supplies() -> void:
	var r := run()
	if r:
		r.player.oxygen = r.stats["max_oxygen"]
		r.player.fuel = r.stats["max_fuel"]


func add_speed(amount: float) -> void:
	var r := run()
	if r == null:
		return
	if r.player.vel.length() > 1.0:
		r.player.vel += r.player.vel.normalized() * amount
	else:
		r.player.vel = Vector2(amount, 0)


func stop() -> void:
	var r := run()
	if r:
		r.player.vel = Vector2.ZERO


func spawn(kind: String) -> void:
	var r := run()
	if r:
		r.debug_spawn(kind)


func style_event(kind: String) -> void:
	var r := run()
	if r == null:
		return
	match kind:
		"points":
			r.style.total += 500
			r.hud.show_trick("DEBUG +500", 500)
		"flip":
			r.style.landed(1.4, 2, true, 55.0)
		"loop":
			r.style.looped()
		"chain":
			for i in 4:
				r.style.net_cut()
		"grind":
			r.style.grind_ended(1.5)
		"canyon":
			r.style.zone_cleared("canyon", 900.0)


# ---- Game state (works on every screen) ----

func max_gear() -> void:
	for id in Balance.UPGRADE_ORDER:
		Game.levels[id] = Balance.upgrade_max(id)
	Game.save_game()
	refresh_screen()


func set_walls(torn: bool) -> void:
	for i in Balance.WALLS.size():
		Game.wall_hp[str(i)] = 0.0 if torn else float(Balance.WALLS[i]["hp"])
	Game.save_game()
	refresh_screen()


func add_tags(amount: int) -> void:
	Game.tags += amount
	Game.save_game()
	refresh_screen()


func play_scene(id: String) -> void:
	if main:
		main.debug_play_scene(id)


func go(screen: String) -> void:
	if main == null:
		return
	match screen:
		"title":
			main.show_title()
		"workshop":
			main.show_workshop()
		"dive":
			main.start_run(true)               # straight into the water, skipping any scene that would play first


func refresh_screen() -> void:
	if main and main._screen is Workshop:
		main.show_workshop()
