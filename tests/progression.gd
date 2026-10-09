extends Node
# Headless check of the dock and save/load: buy upgrades, round-trip a save, test the debug saves.
# Run: godot --headless --path . res://tests/progression.tscn

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _ready() -> void:
	Game.save_path = "user://test_save.json"   # never touch the real save
	Game.save_enabled = false
	Game.debug_reset()
	check(not Game.can_buy("ramp"), "cannot buy with 0 tags")
	Game.tags = 5
	check(Game.buy("ramp") and Game.level("ramp") == 1 and Game.tags == 0, "buy Ramp level 1 for 5 tags")
	# every upgrade changes the stats it promises to
	var base := Balance.stats_for({})
	var maxed := {}
	for id in Balance.UPGRADE_ORDER:
		maxed[id] = Balance.upgrade_max(id)
	var best := Balance.stats_for(maxed)
	check(best["launch_speed"] > base["launch_speed"], "ramp/sled raise launch speed")
	check(best["wing_mult"] > base["wing_mult"], "wing")
	check(best["thrust_mult"] > base["thrust_mult"], "thruster")
	check(best["max_fuel"] > base["max_fuel"], "fuel tank")
	check(best["max_oxygen"] > base["max_oxygen"], "o2 tank")
	check(best["ballast_mult"] > base["ballast_mult"], "ballast")
	check(best["net_slow"] > base["net_slow"] and best["net_slow"] <= 0.98, "cutter")
	check(best["magnet_radius"] > 0.0 and best["pip_arrow"], "pip")
	check(is_equal_approx(best["net_density"], 0.35), "net return level 5 = x0.35")
	check(is_equal_approx(Balance.stats_for({"net_return": 2})["net_density"], 0.70), "net return level 2 = x0.70")
	# caps and endless costs
	Game.tags = 9999
	check(Game.buy("pip") and Game.buy("pip") and Game.buy("pip") and not Game.buy("pip"), "pip stops at level 3 in story mode")
	Game.story_complete = true
	check(Game.buy("pip") and Game.level("pip") == 4, "past the cap in endless")
	check(Balance.upgrade_cost("pip", 3) == int(round(35 * 1.6)), "endless cost = 1.6x the last")
	# save round trip
	Game.save_enabled = true
	Game.debug_mid_save()
	Game.save_game()
	var levels_before := Game.levels.duplicate()
	Game.levels = {}
	Game.tags = 0
	Game.load_game()
	check(Game.levels == levels_before and Game.level("net_return") == 4, "save/load keeps levels as ints")
	Game.debug_reset()   # leave no test save behind
	Game.save_enabled = false
	# the dock builds with and without endless
	for unlocked in [false, true]:
		Game.story_complete = unlocked
		var dock := Dock.new()
		add_child(dock)
		check(dock._cards.size() == 10, "dock has ten cards")
		dock.queue_free()
	for f in failures:
		printerr("PROGRESSION FAIL: ", f)
	print("PROGRESSION ", "FAIL" if failures else "OK")
	get_tree().quit(1 if failures else 0)
