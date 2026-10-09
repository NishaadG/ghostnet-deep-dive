extends Node
# Headless economy simulation. A bot dives with a buying habit, with real Run objects, walls and
# saved wall HP, and we count the dives it needs to clear each net wall and to free the Lumen.
# Run: godot --headless --path . res://tests/economy.tscn -- clumsy=0.5 runs=3
# Target: story done in about 25-35 dives for a casual player; wall 1 around dive 5; first dive 8-15 tags.

# What the simulated player buys first. Cheaper, flashier upgrades come before the big ones.
const BUY_ORDER := ["o2", "ramp", "craft", "fuel", "booster", "cutter", "ballast", "pip", "o2", "ramp",
		"craft", "booster", "cutter", "net_return", "fuel", "o2", "craft", "ramp", "booster", "cutter",
		"net_return", "ballast", "pip", "o2", "craft", "booster", "cutter", "net_return", "net_return", "net_return"]
const MAX_DIVES := 90


func _ready() -> void:
	var clumsy := 0.5
	var runs := 3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("clumsy="):
			clumsy = float(arg.substr(7))
		elif arg.begins_with("runs="):
			runs = int(arg.substr(5))
	Game.save_enabled = false
	var totals: Array[int] = []
	for r in runs:
		var finished_at := _play_through(clumsy, r + 1, r == 0)
		totals.append(finished_at)
		print("RUN %d: story finished on dive %d" % [r + 1, finished_at])
	print("ECONOMY clumsiness %.2f  dives to finish: %s" % [clumsy, str(totals)])
	get_tree().quit()


func _play_through(clumsy: float, seed_value: int, verbose: bool) -> int:
	seed(seed_value)
	Game.new_game(1)
	var bot := FlightBot.new()
	bot.clumsiness = clumsy
	bot.rng.seed = seed_value
	var walls_done := 0
	for dive in range(1, MAX_DIVES + 1):
		Engine.time_scale = 1.0
		var run := Run.new()
		add_child(run)
		run.player.scripted = true
		bot.spawner = run.spawner
		var frames := 0
		while not run.ended and frames < 60 * 150 and not run.lumen_freed:
			bot.steer(run.player)
			run.player._physics_process(1.0 / 60.0)
			run._process(1.0 / 60.0)
			frames += 1
		var result := run.make_result()
		var freed := run.lumen_freed
		run.queue_free()
		await get_tree().process_frame
		Game.bank_run(result)
		var spent := _shop()
		if verbose:
			print("dive %2d: %5d m  %3d tags (now %3d) %s  craft %d booster %d cutter %d  walls %d  %s" % [dive, result["distance_m"], result["tags"],
					Game.tags, spent, Game.level("craft"), Game.level("booster"), Game.level("cutter"), _walls_down(), result["reason"]])
		if freed:
			return dive
		if _walls_down() > walls_done:
			walls_done = _walls_down()
	return MAX_DIVES


func _walls_down() -> int:
	var n := 0
	for i in Balance.WALLS.size():
		if Game.wall_broken(i):
			n += 1
	return n


# Buy the next affordable item from the habit list, repeatedly.
func _shop() -> String:
	var bought: Array[String] = []
	var progress := true
	while progress:
		progress = false
		for id in BUY_ORDER:
			if Game.can_buy(id):
				Game.buy(id)
				bought.append(id)
				progress = true
				break
	return "bought " + ",".join(bought) if not bought.is_empty() else ""
