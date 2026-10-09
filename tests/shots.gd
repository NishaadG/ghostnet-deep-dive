extends Node
# Visual check helper: flies the bot in a real window so --write-movie can capture frames.
# Usage: godot --path . res://tests/shots.tscn --write-movie build/shots/run.png --fixed-fps 30 --quit-after 240 -- x=15000
# "x=N" teleports the dive to N metres-times-ten px (zone preview). "story" keeps walls on.
var run: Run
var bot := FlightBot.new()
var results: Node


func _ready() -> void:
	Game.save_enabled = false
	Game.debug_mid_save()
	var start_x := 0.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("x="):
			start_x = float(arg.substr(2))
	run = Run.new()
	add_child(run)
	run.player.scripted = true
	bot.spawner = run.spawner
	if start_x > 0.0:
		run.terrain.update(start_x)
		run.player.position = Vector2(start_x, run.terrain.floor_y(start_x) - 300.0)
		run.player.state = Player.State.WATER
		run.player.vel = Vector2(520, 120)
		run.player.angle = 0.2
		run.camera.position = run.player.position
		run.pip.position = run.player.position
		run.spawner._frontier = start_x - 300.0
		run.spawner._scanned_to = start_x - 300.0
	run.finished.connect(func(result: Dictionary):
		Game.bank_run(result)
		print("RESULT ", result)
		get_tree().quit())


func _physics_process(_delta: float) -> void:
	if is_instance_valid(run) and not run.ended:
		bot.steer(run.player)
