extends Node
# Global state shared by every screen: upgrade levels now, tags/save in milestone 3.

var levels := {}   # upgrade id -> level; a missing id means level 0
var tags := 0
var best_distance := 0.0
var dives := 0
var animals_freed_total := 0
var wall_hp := {}              # wall index (as text) -> remaining HP; filled in milestone 4
var story_complete := false    # true after the Lumen is freed; unlocks Endless mode
var endless_mode := false
var ui_theme := Theme.new()
var _icons := {}
var font: Font = preload("res://assets/fonts/Poppins-Medium.ttf")
var font_bold: Font = preload("res://assets/fonts/Poppins-Bold.ttf")


var save_path := "user://save.json"      # tests point this at a throwaway file
var save_enabled := true      # tests switch this off so they never touch a real save


func _ready() -> void:
	_setup_input()
	ui_theme.default_font = font
	ui_theme.default_font_size = 18
	load_game()


func level(id: String) -> int:
	return levels.get(id, 0)


# Called by main when a dive ends: bank the tags and update records.
func bank_run(result: Dictionary) -> void:
	tags += int(result["tags"])
	dives += 1
	animals_freed_total += int(result["animals_freed"])
	best_distance = maxf(best_distance, float(result["distance_m"]))
	save_game()


# ---- Upgrades ----

func can_buy(id: String) -> bool:
	var current := level(id)
	if current >= Balance.upgrade_max(id) and not story_complete:
		return false                     # past the cap only in Endless
	return tags >= Balance.upgrade_cost(id, current)


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	tags -= Balance.upgrade_cost(id, level(id))
	levels[id] = level(id) + 1
	save_game()
	return true


func reef_lights() -> int:
	return animals_freed_total


# A sprite cropped to its visible pixels, so big transparent canvases make usable icons.
func icon(sprite_name: String) -> Texture2D:
	if not _icons.has(sprite_name):
		var texture: Texture2D = load("res://assets/sprites/%s.png" % sprite_name)
		var used := texture.get_image().get_used_rect()
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = used if used.size.x > 0 else Rect2(Vector2.ZERO, texture.get_size())
		_icons[sprite_name] = atlas
	return _icons[sprite_name]


# ---- Save / load (user://save.json) ----

func save_game() -> void:
	if not save_enabled:
		return
	var data := {
		"tags": tags, "levels": levels, "wall_hp": wall_hp, "best_distance": best_distance,
		"dives": dives, "animals_freed": animals_freed_total, "story_complete": story_complete,
		"endless_mode": endless_mode,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary:
		return                           # a corrupt save just means a fresh start
	var data: Dictionary = parsed
	tags = int(data.get("tags", 0))
	best_distance = float(data.get("best_distance", 0.0))
	dives = int(data.get("dives", 0))
	animals_freed_total = int(data.get("animals_freed", 0))
	story_complete = bool(data.get("story_complete", false))
	endless_mode = bool(data.get("endless_mode", false)) and story_complete
	levels = {}
	for id in data.get("levels", {}):
		levels[id] = int(data["levels"][id])     # JSON gives floats; levels are whole numbers
	wall_hp = {}
	for key in data.get("wall_hp", {}):
		wall_hp[key] = float(data["wall_hp"][key])


# ---- Debug keys (main.gd calls these on F1 to F4) ----

func debug_reset() -> void:
	levels = {}
	wall_hp = {}
	tags = 0
	best_distance = 0.0
	dives = 0
	animals_freed_total = 0
	story_complete = false
	endless_mode = false
	save_game()


func debug_add_tags() -> void:
	tags += 500
	save_game()


func debug_mid_save() -> void:
	levels = {"ramp": 2, "sled": 2, "wing": 2, "thruster": 1, "fuel": 1, "o2": 2,
			"ballast": 1, "cutter": 2, "pip": 1, "net_return": 4}
	tags = maxi(tags, 100)
	dives = maxi(dives, 12)
	animals_freed_total = maxi(animals_freed_total, 6)
	save_game()


func debug_unlock_endless() -> void:
	story_complete = true
	save_game()


# Input actions are created here (not in project.godot) so the keys are easy to read and change.
func _setup_input() -> void:
	_bind("tilt_up", [KEY_A, KEY_LEFT])
	_bind("tilt_down", [KEY_D, KEY_RIGHT])
	_bind("thrust", [KEY_SPACE])
	_bind("pause", [KEY_ESCAPE])
	_bind("confirm", [KEY_ENTER, KEY_KP_ENTER])


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
