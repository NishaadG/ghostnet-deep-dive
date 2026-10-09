extends Node
# Headless smoke test: starts a real Run, lets the bot fly it for up to 20 simulated seconds
# by stepping the physics by hand, and checks the basics. Exit code 0 = pass.
# Run: godot --headless --path . res://tests/smoke.tscn


func _ready() -> void:
	Game.save_enabled = false
	Game.debug_reset()                       # start from a fresh save, in memory only
	var run := Run.new()
	add_child(run)
	run.player.scripted = true
	var bot := FlightBot.new()
	bot.spawner = run.spawner
	var dt := 1.0 / 60.0
	for frame in int(20.0 / dt):
		bot.steer(run.player)
		run.player._physics_process(dt)
		run._process(dt)
		if run.ended:
			break
	var failures: Array[String] = []
	if run.player.position.x <= 0.0:
		failures.append("distance should be greater than zero")
	if not run.ended:
		failures.append("run should have ended within 20 s")
	if run.nets_cut < 1:
		failures.append("a net should have been cut")
	var result := run.make_result()
	var results := Results.new()           # the results screen must build without errors
	results.result = result
	add_child(results)
	if int(result["fleet_cut"]) < run.nets_cut:
		failures.append("fleet line: loose nets along the way must include the ones we cut")
	print("nets cut %d, fleet cut %d, animals %d, plastic %d, tags %d" % [run.nets_cut, result["fleet_cut"], run.animals_freed, run.plastic, result["tags"]])
	Engine.time_scale = 1.0
	for f in failures:
		printerr("SMOKE FAIL: ", f)
	print("SMOKE %s  distance %d m, reason %s" % ["FAIL" if failures else "OK", run.player.position.x / 10.0, run.end_reason])
	get_tree().quit(1 if failures else 0)
