extends Node
# Headless smoke test: starts a real Run, lets the bot fly it for up to 20 simulated seconds
# by stepping the physics by hand, and checks the basics. Exit code 0 = pass.
# Run: godot --headless --path . res://tests/smoke.tscn


func _ready() -> void:
	var run := Run.new()
	add_child(run)
	run.player.scripted = true
	var bot := FlightBot.new()
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
	# Milestone 2 adds: a net was cut.
	for f in failures:
		printerr("SMOKE FAIL: ", f)
	print("SMOKE %s  distance %d m, reason %s" % ["FAIL" if failures else "OK", run.player.position.x / 10.0, run.end_reason])
	get_tree().quit(1 if failures else 0)
