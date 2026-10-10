extends Node
# Headless check of the sea creatures: each one hurts only when it should, and does what it promises.
# Run: godot --headless --path . res://tests/hazards.tscn

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _ready() -> void:
	Game.save_enabled = false
	Game.save_dir = "user://test_"
	Game.new_game(1)
	var run := Run.new()
	add_child(run)
	var nova := run.player
	nova.state = Player.State.WATER
	nova.position = Vector2(5000, 300)

	# Puffer: harmless while relaxed, spiky once puffed up, and bounces Nova back.
	var puffer := _creature(run, "puffer", nova.position + Vector2(30, 0))
	check(not puffer.touching(nova.position), "a relaxed puffer does not hurt")
	puffer.puff = 1.0
	check(puffer.touching(nova.position), "a puffed-up puffer hurts")
	nova.vel = Vector2(600, 0)
	var oxygen := nova.oxygen
	run._on_hazard_touched(puffer)
	check(nova.vel.x < 0.0 and nova.vel.length() < 600.0, "the puffer bounces Nova back and slows her")
	check(nova.oxygen < oxygen, "the puffer costs oxygen")
	check(not puffer.touching(nova.position), "one touch is one hit (cooldown)")

	# Piranhas: a slow Nova is bitten, a fast one blasts through for style points.
	var school := _creature(run, "piranha", nova.position)
	nova.vel = Vector2(300, 0)
	oxygen = nova.oxygen
	run._on_hazard_touched(school)
	check(nova.oxygen <= oxygen - Balance.PIRANHA_OXYGEN + 0.01, "a piranha bite costs oxygen")
	var fast_school := _creature(run, "piranha", nova.position)
	nova.vel = Vector2(Balance.PIRANHA_OUTRUN + 100.0, 0)
	oxygen = nova.oxygen
	var style_before := run.style.total
	run._on_hazard_touched(fast_school)
	check(is_equal_approx(nova.oxygen, oxygen) and run.style.total > style_before, "fast enough: no bite, style points")

	# Electric ray: the field only hurts while it discharges; a zap stuns the controls.
	var ray := _creature(run, "ray", nova.position + Vector2(Balance.RAY_FIELD - 10.0, 0))
	ray._cycle = 0.0
	check(not ray.touching(nova.position), "a dark ray's field is safe")
	ray._cycle = Balance.RAY_PERIOD - Balance.RAY_DISCHARGE / 2.0
	check(ray.discharging() and ray.touching(nova.position), "a discharging ray's field hurts")
	run._on_hazard_touched(ray)
	check(nova.stunned > 0.0, "the ray stuns Nova")
	nova.scripted = true
	nova.tilt_input = 1.0
	nova.thrust_input = true
	nova._physics_process(1.0 / 60.0)
	check(nova.tilt_input == 0.0 and not nova.thrusting, "a stunned Nova cannot steer or boost")

	# Spawning: creatures appear in their zones, never right before a net wall.
	var spawner := run.spawner
	for i in 40:
		spawner._spawn_hazards(14000.0 + i * Spawner.SLICE)
	check(spawner.hazards.size() > 0, "creatures spawn in the Drowned City")
	for hazard in spawner.hazards:
		check(not spawner._near_wall(hazard.position.x), "no creature placed just before a wall")
	for f in failures:
		printerr("HAZARDS FAIL: ", f)
	print("HAZARDS %s" % ("FAIL" if failures else "OK"))
	get_tree().quit(1 if failures else 0)


func _creature(run: Run, kind: String, at: Vector2) -> Hazard:
	var hazard := Hazard.new()
	hazard.setup(kind, at, 3)
	hazard.player = run.player
	run.add_child(hazard)
	return hazard
