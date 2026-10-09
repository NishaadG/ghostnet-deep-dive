extends Node
# How far can the bot get with a given kit and NO walls (Endless)? Used to find broken zones.
# Run: godot --headless --path . res://tests/zones.tscn
func _ready() -> void:
	Game.save_enabled = false
	for kit in [{"craft": 2, "booster": 2, "cutter": 2, "ramp": 2, "o2": 3, "fuel": 2}, {"craft": 5, "booster": 5, "cutter": 5, "ramp": 6, "o2": 6, "fuel": 5, "ballast": 2}]:
		for seed_value in [1, 2, 3]:
			Game.new_game(1)
			Game.endless_mode = true
			Game.levels = kit.duplicate()
			seed(seed_value)
			var run := Run.new()
			add_child(run)
			run.player.scripted = true
			var bot := FlightBot.new()
			bot.spawner = run.spawner
			bot.rng.seed = seed_value
			var frames := 0
			var log := ""
			while not run.ended and frames < 60 * 200:
				bot.steer(run.player)
				run.player._physics_process(1.0 / 60.0)
				run._process(1.0 / 60.0)
				frames += 1
			print("kit craft %d: seed %d  %d m  depth %d m  %.0f s  top %d  end %s" % [kit["craft"], seed_value, run.player.position.x / 10.0, run.max_depth_m, frames / 60.0, run.top_speed, run.end_reason])
			run.queue_free()
			await get_tree().process_frame
	get_tree().quit()
