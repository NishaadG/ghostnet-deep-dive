extends Node
# Headless check of upgrades, slots and save/load. Uses throwaway save files, never your real ones.
# Run: godot --headless --path . res://tests/progression.tscn

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _ready() -> void:
	Game.save_dir = "user://test_"
	Game.new_game(1)
	check(not Game.can_buy("craft"), "cannot buy with 0 tags")
	Game.tags = 100
	check(Game.buy("craft") and Game.level("craft") == 1 and Game.tags == 100 - Balance.upgrade_cost("craft", 0), "buy Skim Sled")
	check(Balance.owned_name("craft", 1) == "Skim Sled", "craft tier 1 is the Skim Sled")
	# every upgrade changes the stats it promises to
	var base := Balance.stats_for({})
	var maxed := {}
	for id in Balance.UPGRADE_ORDER:
		maxed[id] = Balance.upgrade_max(id)
	var best := Balance.stats_for(maxed)
	check(best["launch_speed"] > base["launch_speed"], "ramp and craft raise launch speed")
	check(best["wing_mult"] > base["wing_mult"], "craft raises wing turn")
	check(best["thrust_mult"] > base["thrust_mult"], "booster")
	check(best["max_fuel"] > base["max_fuel"], "fuel tank")
	check(best["max_oxygen"] > base["max_oxygen"], "air tank")
	check(best["ballast_mult"] > base["ballast_mult"], "ballast")
	check(best["net_slow"] > base["net_slow"] and best["net_slow"] <= 0.98, "cutter")
	check(best["magnet_radius"] > 0.0 and best["pip_arrow"], "pip")
	check(is_equal_approx(best["net_density"], 0.35), "net return level 5 = x0.35")
	check(is_equal_approx(Balance.stats_for({"net_return": 2})["net_density"], 0.70), "net return level 2 = x0.70")
	# caps and endless
	Game.tags = 99999
	check(Game.buy("pip") and Game.buy("pip") and Game.buy("pip") and not Game.buy("pip"), "pip stops at level 3 in story mode")
	for i in 5:
		Game.buy("craft")
	check(Game.level("craft") == Balance.upgrade_max("craft") and not Game.buy("craft"), "gear stops at its top tier")
	Game.story_complete = true
	check(Game.buy("pip") and Game.level("pip") == 4, "plain upgrades go past the cap in Endless")
	check(not Game.can_buy("craft"), "gear never goes past the top tier")
	check(Balance.upgrade_cost("pip", 3) == int(round(220 * Balance.COST_SCALE * 1.6)), "endless cost = 1.6x the last")
	# walls
	check(Game.next_wall() == 0, "first wall is next")
	Game.wall_hp["0"] = 0.0
	check(Game.wall_broken(0) and Game.next_wall() == 1, "a broken wall moves on to the next")
	# slots: save, summary, reload, delete
	Game.save_game()
	var summary := Game.slot_summary(1)
	check(int(summary.get("tags", -1)) == Game.tags, "slot summary shows saved tags")
	var levels_before := Game.levels.duplicate()
	Game.continue_game(1)
	check(Game.levels == levels_before and Game.slot == 1, "continue_game restores levels as ints")
	check(Game.wall_broken(0), "wall HP survives a save")
	check(Game.slot_summary(2).is_empty(), "an unused slot is empty")
	Game.delete_slot(1)
	check(Game.slot_summary(1).is_empty(), "deleted slot is empty")
	# tags formula: one tag per 20 m
	check(Balance.tags_for(120.0, 80.0, 2, 1, 0) == 3 + 2 + 2 + 3, "tags formula")
	# screens build without errors
	Game.new_game(1)
	for screen in [Title.new(), SlotSelect.new(), Workshop.new(), SettingsPanel.new(), PauseMenu.new()]:
		add_child(screen)
		await get_tree().process_frame
		screen.queue_free()
	Game.delete_slot(1)
	for f in failures:
		printerr("PROGRESSION FAIL: ", f)
	print("PROGRESSION ", "FAIL" if failures else "OK")
	get_tree().quit(1 if failures else 0)
