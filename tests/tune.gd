extends Node
# Headless tuning helper: flies the bot with different upgrade sets and prints how far it gets.
# Run: godot --headless --path . res://tests/tune.tscn


func _ready() -> void:
	var sets := {
		"no upgrades": {},
		"ramp2 sled1": {"ramp": 2, "sled": 1},
		"wing3": {"wing": 3},
		"maxed": {"ramp": 5, "sled": 4, "wing": 5, "thruster": 4, "fuel": 4, "o2": 5, "ballast": 4},
	}
	for label in sets:
		for seed_value in [1, 2, 3]:
			print("%-14s seed %d  %s" % [label, seed_value, _fly(sets[label], seed_value)])
	get_tree().quit()


func _fly(levels: Dictionary, seed_value: int) -> String:
	var terrain := Terrain.new()
	terrain.setup(seed_value)
	var player := Player.new()
	player.scripted = true
	player.start(Balance.stats_for(levels), terrain)
	var reason := [""]
	player.ended.connect(func(r: String): reason[0] = r)
	var bot := FlightBot.new()
	var top := 0.0
	var t := 0.0
	while player.state != Player.State.DONE and t < 120.0:
		terrain.update(player.position.x)
		bot.steer(player)
		player._physics_process(1.0 / 60.0)
		top = maxf(top, player.vel.length())
		t += 1.0 / 60.0
	return "%5.1f s  dist %4d m  depth %3d m  top %4d px/s  end: %s" % [t, player.position.x / 10.0, player.position.y / 10.0, top, reason[0]]
