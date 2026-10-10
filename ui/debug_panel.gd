class_name DebugPanel
extends Control
# The developer panel (F9). A side panel with teleports, cheats, spawners, trick tests, story scenes
# and game-state shortcuts. All real work is in autoload/debug.gd; this file only builds buttons.

var _info: Label
var _toggle_buttons := {}            # cheat name -> Button, so the label can show ON/OFF
var _box: VBoxContainer
var _metres_edit: LineEdit


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE                   # clicks outside the panel still reach the game
	add_child(UiKit.panel(Vector2(896, 8), Vector2(376, 704), Art.MAGENTA, 0.9))
	var title := UiKit.label("DEBUG    F9 closes", 18, true, Art.MAGENTA.lightened(0.3))
	title.position = Vector2(912, 14)
	add_child(title)
	_info = UiKit.label("", 12, false, Art.ICE)
	_info.position = Vector2(912, 42)
	_info.size = Vector2(350, 70)
	add_child(_info)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(906, 118)
	scroll.size = Vector2(358, 586)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_box = VBoxContainer.new()
	_box.custom_minimum_size = Vector2(340, 0)
	_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_box)
	_build()


func _process(_delta: float) -> void:
	_info.text = _info_text()
	for cheat in _toggle_buttons:
		(_toggle_buttons[cheat] as Button).text = "%s  %s" % ["[ON] " if Debug.cheats[cheat] else "[off]", _cheat_label(cheat)]


func _info_text() -> String:
	var text := "fps %d    screen %s    time x%.2f" % [Engine.get_frames_per_second(), Debug.screen_name(), Engine.time_scale]
	var r := Debug.run()
	if r:
		var p := r.player
		text += "\nx %d m   y %d m   speed %d   state %s" % [p.position.x / 10.0, p.position.y / 10.0, p.vel.length(), Player.State.keys()[p.state]]
		text += "\nO2 %.1f   fuel %.1f   zone %s" % [p.oxygen, p.fuel, Balance.zone_id_at(p.position.x)]
		text += "\nstyle %d   chain %d x%.2f   tags %d" % [r.style.total, r.style.chain, r.style.multiplier, r.tags_so_far()]
	else:
		text += "\ntags %d   dives %d   slot %d" % [Game.tags, Game.dives, Game.slot]
	return text


func _cheat_label(cheat: String) -> String:
	return {"god": "God mode (no crashes, creatures harmless)", "oxygen": "Infinite O2", "fuel": "Infinite fuel",
			"wall_kill": "Walls die in one hit", "no_creatures": "No sea creatures"}[cheat]


# ---- Layout ----

func _build() -> void:
	_heading("TELEPORT (in a dive)")
	var teleports := []
	for entry in Debug.TELEPORTS:
		teleports.append([str(entry[0]), func(): Debug.teleport(float(entry[1]))])
	teleports.append_array([["Next wall", Debug.teleport_to_next_wall], ["Next canyon", func(): Debug.teleport_to_next_zone("canyon")],
			["Next drop", func(): Debug.teleport_to_next_zone("drop")]])
	_grid(teleports)
	_metres_row()
	_heading("CHEATS")
	for cheat in ["god", "oxygen", "fuel", "wall_kill", "no_creatures"]:
		_toggle(cheat)
	_grid([["Fill O2 + fuel", Debug.fill_supplies], ["+400 speed", func(): Debug.add_speed(400.0)], ["Stop", Debug.stop]])
	_heading("SPAWN IN FRONT")
	_grid([["Net", func(): Debug.spawn("net")], ["Net + animal", func(): Debug.spawn("animal")],
			["O2 canister", func(): Debug.spawn("o2")], ["Fuel cell", func(): Debug.spawn("fuel")],
			["Piranha school", func(): Debug.spawn("piranha")], ["Puffer fish", func(): Debug.spawn("puffer")],
			["Electric ray", func(): Debug.spawn("ray")]])
	_heading("TRICK TESTS")
	_grid([["+500 style", func(): Debug.style_event("points")], ["2 flips", func(): Debug.style_event("flip")],
			["Loop", func(): Debug.style_event("loop")], ["Net chain x4", func(): Debug.style_event("chain")],
			["Grind", func(): Debug.style_event("grind")], ["Canyon clear", func(): Debug.style_event("canyon")]])
	_heading("STORY SCENES")
	var scenes := []
	for id in Story.ORDER:
		scenes.append([id, func(): Debug.play_scene(id)])
	_grid(scenes)
	_heading("GAME STATE")
	_grid([["+500 tags", func(): Debug.add_tags(500)], ["Max all gear", Debug.max_gear],
			["Tear all walls", func(): Debug.set_walls(true)], ["Restore walls", func(): Debug.set_walls(false)],
			["Unlock Endless", Game.debug_unlock_endless], ["Unlock scenes", Game.debug_unlock_scenes],
			["Reset slot", func(): Game.debug_reset(); Debug.refresh_screen()], ["Mid-game save", func(): Game.debug_mid_save(); Debug.refresh_screen()]])
	_heading("GO TO")
	_grid([["Title", func(): Debug.go("title")], ["Workshop", func(): Debug.go("workshop")], ["New dive", func(): Debug.go("dive")]])


func _heading(text: String) -> void:
	var label := UiKit.label(text, 12, true, Color(Art.AMBER, 0.95))
	label.custom_minimum_size = Vector2(340, 20)
	_box.add_child(label)


# A two-column grid of small buttons. entries: [[text, Callable], ...]
func _grid(entries: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for entry in entries:
		var button := UiKit.button(entry[0], Vector2(166, 30), Art.CYAN, false, 13)
		button.pressed.connect(entry[1])
		grid.add_child(button)
	_box.add_child(grid)


func _toggle(cheat: String) -> void:
	var button := UiKit.button("", Vector2(340, 30), Art.MAGENTA, false, 13)
	button.pressed.connect(func(): Debug.toggle_cheat(cheat))
	_box.add_child(button)
	_toggle_buttons[cheat] = button


# Type any distance in metres and jump there.
func _metres_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_metres_edit = LineEdit.new()
	_metres_edit.placeholder_text = "metres, e.g. 2000"
	_metres_edit.custom_minimum_size = Vector2(200, 30)
	_metres_edit.text_submitted.connect(func(_text: String): _go_to_typed_metres())
	row.add_child(_metres_edit)
	var go := UiKit.button("GO", Vector2(80, 30), Art.CYAN, true, 13)
	go.pressed.connect(_go_to_typed_metres)
	row.add_child(go)
	_box.add_child(row)


func _go_to_typed_metres() -> void:
	if _metres_edit.text.is_valid_float():
		Debug.teleport(float(_metres_edit.text))
	_metres_edit.release_focus()
