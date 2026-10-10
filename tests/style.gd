extends Node
# Unit checks for the evaluation system: scoring, chains, ranks, flips and loops.
# Run: godot --headless --path . res://tests/style.tscn

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _ready() -> void:
	Game.save_enabled = false
	_scoring()
	await _flips_and_loops()
	for f in failures:
		printerr("STYLE FAIL: ", f)
	print("STYLE ", "FAIL" if failures else "OK")
	get_tree().quit(1 if failures else 0)


func _scoring() -> void:
	var s := StyleScore.new()
	s.net_cut()
	check(s.chain == 1 and is_equal_approx(s.multiplier, 1.0) and s.total == 0, "first net starts a chain, no points yet")
	s.net_cut()
	check(s.chain == 2 and is_equal_approx(s.multiplier, 1.25), "second net inside the window raises the multiplier")
	check(s.total == int(Balance.CHAIN_POINTS * 2), "chain points scale with chain length")
	s.update(Balance.CHAIN_WINDOW + 0.1)
	check(s.chain == 0 and is_equal_approx(s.multiplier, 1.0), "the chain dies when its window runs out")
	check(s.best_chain == 2, "best chain is remembered")
	var t := StyleScore.new()
	t.landed(1.0, 1, true, 50.0)
	check(t.total == int(Balance.AIR_POINTS_PER_S + Balance.FLIP_POINTS + Balance.PERFECT_SPLASH_POINTS), "airtime + flip + perfect splash")
	var u := StyleScore.new()
	u.landed(1.2, 2, false, 120.0)
	check(u.total == 0, "a bailed landing scores nothing")
	var v := StyleScore.new()
	for c in 3:
		v.net_cut()                                  # multiplier 1.5 after three nets
	var before := v.total
	v.looped()
	check(v.total - before == int(round(Balance.LOOP_POINTS * 1.5)), "the chain multiplier boosts a loop")
	var r := StyleScore.new()
	r.total = 0
	check(r.rank() == "D", "no points is rank D")
	r.total = 460
	check(r.rank() == "B", "460 points is rank B")
	r.total = 5000
	check(r.rank() == "S", "5000 points is rank S")
	check(r.tag_bonus(10) == int(ceil(10 * Balance.STYLE_TAG_CAP)) + 1, "style tags are capped by the dive's normal tags")
	check(r.tag_bonus(1000) == 5000 / Balance.STYLE_POINTS_PER_TAG, "a big dive can convert all its points")
	Game.new_game(1)
	Game.bank_run({"tags": 5, "animals_freed": 0, "nets_cut": 0, "distance_m": 10.0, "style": {"total": 900, "rank": "A"}})
	Game.bank_run({"tags": 5, "animals_freed": 0, "nets_cut": 0, "distance_m": 10.0, "style": {"total": 100, "rank": "C"}})
	check(Game.best_style == 900 and Game.best_rank == "A", "best style and rank are kept")


func _make_player(y: float) -> Player:
	var terrain := Terrain.new()
	terrain.setup(1)
	terrain.points = PackedVector2Array([Vector2(-3000, 5000), Vector2(90000, 5000)])
	var p := Player.new()
	p.scripted = true
	p.start(Balance.stats_for({}), terrain)
	p.position = Vector2(1000, y)
	add_child(p)
	return p


func _flips_and_loops() -> void:
	var p := _make_player(-900.0)
	p.state = Player.State.AIR
	p._begin_air()
	p.vel = Vector2(400, 0)
	p.angle = 0.0
	var flips := [0]
	var landing := {}
	p.flipped.connect(func(): flips[0] += 1)
	p.landed.connect(func(air: float, count: int, clean: bool, deg: float): landing.merge({"air": air, "flips": count, "clean": clean, "deg": deg}, true))
	for i in 600:
		p.tilt_input = 1.0 if i < 70 else 0.0                     # about one full rotation at 380 deg/s
		p._physics_process(1.0 / 60.0)
		if p.state == Player.State.WATER:
			break
	check(flips[0] >= 1, "a full spin in the air counts as a flip")
	check(landing.has("flips") and landing["flips"] >= 1 and landing["air"] > 1.0, "landed reports airtime and flips")
	p.queue_free()

	var q := _make_player(4650.0)                                  # corridor 700 px: ceiling at 4300, floor at 5000
	q.state = Player.State.WATER
	q.vel = Vector2(700, 0)
	q.angle = Balance.ANGLE_MIN
	q.oxygen = 99.0
	var loops := [0]
	q.looped.connect(func(): loops[0] += 1)
	for i in 300:
		q.tilt_input = -1.0
		q._physics_process(1.0 / 60.0)
		if loops[0] > 0 or q.state == Player.State.DONE:
			break
	check(loops[0] == 1, "holding nose-up at speed with room to spare performs one loop (state %d)" % q.state)
	check(q.angle >= Balance.ANGLE_MIN - 0.01 and q.angle <= Balance.ANGLE_MAX, "after a loop the nose is back in its normal range")
	q.queue_free()
	var cramped := _make_player(4650.0)
	cramped.state = Player.State.WATER
	cramped.vel = Vector2(1200, 0)                                  # too fast: the loop would not fit
	cramped.angle = Balance.ANGLE_MIN
	cramped.oxygen = 99.0
	for i in 12:                                                    # drag slows her fast, so only judge the first moments
		cramped.tilt_input = -1.0
		cramped._physics_process(1.0 / 60.0)
	check(not cramped.looping, "no loop starts without enough room")
	cramped.queue_free()
	await get_tree().process_frame
