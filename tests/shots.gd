extends Node
# Visual check helper: flies the bot in a real window so --write-movie can capture frames.
# Run: godot --path . res://tests/shots.tscn --write-movie build/shots/run.png --fixed-fps 30 --quit-after 480
var run: Run
var bot := FlightBot.new()
var results: Results


func _ready() -> void:
	Game.save_enabled = false
	Game.debug_mid_save()
	run = Run.new()
	add_child(run)
	run.player.scripted = true
	bot.spawner = run.spawner
	run.finished.connect(func(result: Dictionary):
		Game.bank_run(result)
		run.queue_free()
		results = Results.new()
		results.result = result
		add_child(results))


func _physics_process(_delta: float) -> void:
	if is_instance_valid(run) and not run.ended:
		bot.steer(run.player)
