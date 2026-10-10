extends Node
# Global state shared by every screen: the loaded save slot, settings, and upgrade rules.
# Three save slots live in user://save_1.json ... save_3.json; settings in user://settings.json.

const SLOT_COUNT := 3

var slot := 0                  # 0 = no slot loaded yet; 1..3 once the player picks one
var levels := {}               # upgrade id -> level / gear tier; a missing id means 0
var tags := 0
var best_distance := 0.0
var dives := 0
var animals_freed_total := 0
var nets_cut_total := 0
var best_style := 0          # highest style score in one dive
var best_rank := ""          # best rank earned (D to S)
var wall_hp := {}              # wall index (as text) -> remaining HP; missing = untouched
var story_complete := false    # true after the Lumen is freed; unlocks Endless mode
var endless_mode := false

var settings := {"master": 0.8, "music": 0.7, "sfx": 0.9, "music_on": true, "sfx_on": true,
		"fullscreen": false, "shake": true, "touch": false, "last_slot": 0}
var save_enabled := true       # tests switch this off so they never touch a real save
var save_dir := "user://"      # tests point this at a throwaway folder name prefix
var ui_theme := Theme.new()
var font: Font = preload("res://assets/fonts/Poppins-Medium.ttf")
var font_bold: Font = preload("res://assets/fonts/Poppins-Bold.ttf")


func _ready() -> void:
	_setup_input()
	ui_theme.default_font = font
	ui_theme.default_font_size = 18
	# Phones start with the touch controls on.
	if DisplayServer.is_touchscreen_available():
		settings["touch"] = true
	load_settings()


func level(id: String) -> int:
	return levels.get(id, 0)


# ---- Walls (story goals) ----

func wall_remaining(index: int) -> float:
	return wall_hp.get(str(index), Balance.WALLS[index]["hp"])


func wall_broken(index: int) -> bool:
	return wall_remaining(index) <= 0.0


# The next wall that still stands, or -1 when all four are down.
func next_wall() -> int:
	for i in Balance.WALLS.size():
		if not wall_broken(i):
			return i
	return -1


# ---- Upgrades ----

func can_buy(id: String) -> bool:
	var current := level(id)
	if current >= Balance.upgrade_max(id):
		# Only plain upgrades go past the cap, and only in Endless once the story is done.
		if Balance.is_gear(id) or not story_complete:
			return false
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


# Called by main when a dive ends: bank the tags and update records.
func bank_run(result: Dictionary) -> void:
	tags += int(result["tags"])
	dives += 1
	animals_freed_total += int(result["animals_freed"])
	nets_cut_total += int(result["nets_cut"])
	best_distance = maxf(best_distance, float(result["distance_m"]))
	var style: Dictionary = result.get("style", {})
	if not style.is_empty():
		best_style = maxi(best_style, int(style["total"]))
		best_rank = _better_rank(best_rank, String(style["rank"]))
	save_game()


# Ranks run S (best) to D; an empty string means none yet.
func _better_rank(current: String, candidate: String) -> String:
	var order := ["", "D", "C", "B", "A", "S"]
	return candidate if order.find(candidate) > order.find(current) else current


# ---- Save slots ----

func slot_path(slot_number: int) -> String:
	return "%ssave_%d.json" % [save_dir, slot_number]


# What the slot-select screen shows. Empty dictionary = empty slot.
func slot_summary(slot_number: int) -> Dictionary:
	var path := slot_path(slot_number)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	return parsed


func new_game(slot_number: int) -> void:
	slot = slot_number
	_clear_progress()
	save_game()


func continue_game(slot_number: int) -> void:
	slot = slot_number
	_clear_progress()
	_apply(slot_summary(slot_number))


func delete_slot(slot_number: int) -> void:
	if FileAccess.file_exists(slot_path(slot_number)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot_number)))


func save_game() -> void:
	if not save_enabled or slot == 0:
		return
	var data := {
		"tags": tags, "levels": levels, "wall_hp": wall_hp, "best_distance": best_distance,
		"dives": dives, "animals_freed": animals_freed_total, "nets_cut": nets_cut_total,
		"best_style": best_style, "best_rank": best_rank,
		"story_complete": story_complete, "endless_mode": endless_mode,
		"saved_at": Time.get_datetime_string_from_system(),
	}
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func _clear_progress() -> void:
	levels = {}
	wall_hp = {}
	tags = 0
	best_distance = 0.0
	dives = 0
	animals_freed_total = 0
	nets_cut_total = 0
	best_style = 0
	best_rank = ""
	story_complete = false
	endless_mode = false


func _apply(data: Dictionary) -> void:
	tags = int(data.get("tags", 0))
	best_distance = float(data.get("best_distance", 0.0))
	dives = int(data.get("dives", 0))
	animals_freed_total = int(data.get("animals_freed", 0))
	nets_cut_total = int(data.get("nets_cut", 0))
	best_style = int(data.get("best_style", 0))
	best_rank = String(data.get("best_rank", ""))
	story_complete = bool(data.get("story_complete", false))
	endless_mode = bool(data.get("endless_mode", false)) and story_complete
	levels = {}
	for id in data.get("levels", {}):
		levels[id] = int(data["levels"][id])     # JSON gives floats; levels are whole numbers
	wall_hp = {}
	for key in data.get("wall_hp", {}):
		wall_hp[key] = float(data["wall_hp"][key])


# ---- Settings (shared by all slots) ----

func load_settings() -> void:
	var path := save_dir + "settings.json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			for key in settings:
				if parsed.has(key):
					settings[key] = parsed[key]
	apply_settings()


func save_settings() -> void:
	if not save_enabled:
		return
	var file := FileAccess.open(save_dir + "settings.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))


# Volumes are applied by the Audio autoload; fullscreen is applied here.
func apply_settings() -> void:
	if not DisplayServer.get_name() == "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)


# ---- Debug keys (main.gd calls these on F1 to F4) ----

func debug_reset() -> void:
	_clear_progress()
	save_game()


func debug_add_tags() -> void:
	tags += 500
	save_game()


func debug_mid_save() -> void:
	levels = {"craft": 2, "booster": 2, "cutter": 2, "ramp": 2, "fuel": 1, "o2": 2,
			"ballast": 1, "pip": 1, "net_return": 4}
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
