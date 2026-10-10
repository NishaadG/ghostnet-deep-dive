extends Node
# Builds one menu screen for a screenshot: godot --path . res://tests/menu_shot.tscn --write-movie out.png --quit-after 90 -- screen=workshop
func _ready() -> void:
	Game.save_enabled = false
	Game.save_dir = "user://test_"
	Game.slot = 1
	Game.debug_mid_save()
	var which := "title"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("screen="):
			which = arg.substr(7)
	var screen: Node
	match which:
		"title":
			screen = Title.new()
		"slots":
			screen = SlotSelect.new()
		"workshop":
			screen = Workshop.new()
			if "tab=1" in OS.get_cmdline_user_args():
				screen._tab = 1
			if "tab=2" in OS.get_cmdline_user_args():
				screen._tab = 2
		"results":
			var r := Results.new()
			r.result = {"reason": "wall", "distance_m": 412.0, "max_depth_m": 88.0, "top_speed": 760.0, "nets_cut": 5, "animals_freed": 2,
					"plastic": 11, "wall_bonus": 0, "fleet_cut": 9, "tags": 41, "lumen_freed": false,
					"wall_info": {"name": "Reef Gate", "before": 1100.0, "after": 640.0, "max": 1400.0}}
			screen = r
		"cutscene":                          # -- screen=cutscene scene=intro beat=3
			var c := Cutscene.new()
			var id := "intro"
			var beat := 0
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("scene="):
					id = arg.substr(6)
				if arg.begins_with("beat="):
					beat = int(arg.substr(5))
			c.setup(id)
			screen = c
			add_child(screen)
			for i in beat:
				c._typed = 9999.0
				c._auto_wait = -1.0
				c._next()
			return
		"gallery":
			screen = StoryGallery.new()
		"settings":
			screen = SettingsPanel.new()
		"pause":
			screen = PauseMenu.new()
	add_child(screen)
