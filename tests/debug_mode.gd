extends Node
# Checks the developer tools: teleports (forward and back), cheats, spawning and the panel itself.
# Run: godot --headless --path . res://tests/debug_mode.tscn

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _step(run: Run, frames: int) -> void:
	for i in frames:
		run.player._physics_process(1.0 / 60.0)
		run._process(1.0 / 60.0)


func _ready() -> void:
	Game.save_enabled = false
	Game.new_game(1)
	var run := Run.new()
	add_child(run)
	run.player.scripted = true
	Debug.main = null                               # the panel can build without a main scene
	_step(run, 5)
	for metres in [2900.0, 100.0, 3650.0, 0.0, 1600.0]:                # forward, back (terrain rebuilt), far forward, start, mid
		run.debug_teleport(metres)
		_step(run, 30)
		check(absf(run.player.position.x / 10.0 - metres) < 80.0, "teleport to %d m lands near it (at %d m)" % [metres, run.player.position.x / 10.0])
		var floor_y := run.terrain.floor_y(run.player.position.x)
		check(run.player.position.y < floor_y and run.player.state != Player.State.DONE, "after teleporting to %d m Nova is inside the corridor and alive" % metres)
	# cheats
	Debug.cheats["oxygen"] = true
	run.player.oxygen = 1.0
	_step(run, 10)
	check(run.player.oxygen >= run.stats["max_oxygen"] - 0.01, "infinite oxygen keeps the tank full")
	Debug.cheats["oxygen"] = false
	Debug.cheats["god"] = true
	var floor_here := run.terrain.floor_y(run.player.position.x)
	run.player.position.y = floor_here - 40.0
	run.player.vel = Vector2(0, 900)                                    # slamming into the floor would normally end the run
	_step(run, 6)
	check(run.player.state != Player.State.DONE, "god mode survives a crash")
	Debug.cheats["god"] = false
	# spawning
	var nets_before := run.spawner.nets.size()
	run.debug_spawn("animal")
	run.debug_spawn("o2")
	check(run.spawner.nets.size() == nets_before + 1 and run.spawner.pickups.size() >= 1, "spawn adds a net and a pickup")
	# helpers through the Debug singleton (they use main, so only the ones that do not)
	Debug.cheats["wall_kill"] = true
	check(Debug.is_on("wall_kill"), "cheat flags can be switched on")
	Debug.cheats["wall_kill"] = false
	# style test buttons
	var before := run.style.total
	run.style.looped()
	check(run.style.total > before, "trick tests add points")
	# the panel builds, updates and closes
	Debug.toggle_panel()
	await get_tree().process_frame
	await get_tree().process_frame
	Debug.toggle_panel()
	await get_tree().process_frame
	run.queue_free()
	await _through_main()
	for f in failures:
		printerr("DEBUG FAIL: ", f)
	print("DEBUG MODE ", "FAIL" if failures else "OK")
	get_tree().quit(1 if failures else 0)


# Drive the real main scene through the Debug singleton, the way the panel's buttons do.
func _through_main() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	check(Debug.main == main, "main registers itself with the Debug singleton")
	Debug.go("workshop")
	await get_tree().process_frame
	check(Debug.screen_name() == "Workshop", "go(workshop) shows the workshop (got %s)" % Debug.screen_name())
	Debug.max_gear()
	check(Game.level("craft") == Balance.upgrade_max("craft"), "max gear sets every upgrade to its cap")
	Debug.set_walls(true)
	check(Game.wall_broken(0) and Game.wall_broken(3), "tear all walls")
	Debug.set_walls(false)
	check(not Game.wall_broken(0), "restore walls")
	Debug.go("dive")
	await get_tree().process_frame
	await get_tree().process_frame
	var dive := Debug.run()
	check(dive != null, "go(dive) starts a run")
	if dive:
		Debug.teleport_to_next_wall()
		check(dive.player.position.x / 10.0 > 300.0, "teleport to next wall moves Nova to it")
		Debug.teleport_to_next_zone("canyon")
		Debug.fill_supplies()
		Debug.play_scene("wall0_meet")                       # plays over the dive and pauses it
		await get_tree().process_frame
		check(get_tree().paused, "a scene played over a dive pauses it")
		get_tree().paused = false
	main.queue_free()
	await get_tree().process_frame
