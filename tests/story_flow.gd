extends Node
# Headless check that cutscenes are wired into the game flow: a wall's meeting scene pauses the
# dive and resumes it, torn walls and the ending play before the results, and the Net Return
# scene plays once before the next dive. Uses throwaway saves.
# Run: godot --headless --path . res://tests/story_flow.tscn

var failures: Array[String] = []
var main: Node


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _ready() -> void:
	Game.save_enabled = false
	Game.save_dir = "user://test_"
	Game.new_game(1)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	# 1. A wall comes into view: the dive pauses under the cutscene, then carries on.
	main.start_run()
	var run: Run = main._screen
	run.story_moment.emit("wall0_meet")
	check(get_tree().paused, "the dive pauses for a wall scene")
	check(main._overlay is CanvasLayer, "the wall scene plays on top of the dive")
	await _click_through((main._overlay as CanvasLayer).get_child(0))
	check(not get_tree().paused and main._overlay == null, "the dive resumes after the wall scene")
	check(Game.scene_seen("wall0_meet"), "the wall scene is remembered")
	# 2. A dive that tore wall 0 and freed the Lumen: both scenes, then the results.
	var result := run.make_result()
	result["walls_torn"] = [0, 3]
	result["lumen_freed"] = true
	main._on_run_finished(result)
	check(main._screen is Cutscene and (main._screen as Cutscene).scene_id == "wall0_torn", "torn wall scene after the dive")
	await _click_through(main._screen)
	check(main._screen is Cutscene and (main._screen as Cutscene).scene_id == "ending", "ending after the torn wall")
	await _click_through(main._screen)
	check(main._screen is Results, "results after the scenes")
	# 3. Net Return bought: its scene plays once, before the next dive.
	Game.levels["net_return"] = 1
	main.start_run()
	check(main._screen is Cutscene and (main._screen as Cutscene).scene_id == "net_return", "Net Return scene before the dive")
	await _click_through(main._screen)
	check(main._screen is Run, "the dive starts after the Net Return scene")
	main.start_run()
	check(main._screen is Run, "the Net Return scene plays only once")
	get_tree().paused = false
	for f in failures:
		printerr("STORY FLOW FAIL: ", f)
	print("STORY FLOW %s" % ("FAIL" if failures else "OK"))
	get_tree().quit(1 if failures else 0)


func _click_through(cutscene: Cutscene) -> void:
	var frames := 0
	while not cutscene._done and frames < 3000:
		await get_tree().process_frame
		frames += 1
		if frames % 4 == 0:
			cutscene.advance()
	check(cutscene._done, "%s finished" % cutscene.scene_id)
	await get_tree().process_frame
