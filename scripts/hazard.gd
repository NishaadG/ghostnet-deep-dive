class_name Hazard
extends Node2D
# Sea creatures that get in Nova's way. They cannot be cut; touching them costs oxygen and speed.
# Each one is easy to read and has a clear way to beat it:
#   piranha  a school that darts at Nova when she comes near. Fast enough, and she blasts straight through.
#   puffer   floats still, then puffs up into a spiky ball when Nova gets close. Its spikes bounce her back.
#   ray      an electric ray gliding to and fro. It glows brighter (the warning), then discharges a ring
#            that stuns her for a moment. Pass while it is dark.
# The spawner places them and tests touches; run.gd applies what a touch does (numbers in balance.gd).

const BODY_RADIUS := {"piranha": 48.0, "puffer": 20.0, "ray": 42.0}

var kind := "puffer"
var player: Player
var terrain: Terrain
var cooldown := 0.0            # seconds after a hit when this creature cannot hit again
var puff := 0.0                # puffer: 0 relaxed .. 1 fully puffed up
var _home := Vector2.ZERO
var _vel := Vector2.ZERO
var _age := 0.0
var _cycle := 0.0              # ray: seconds into its charge/discharge cycle
var _facing := -1.0            # -1 looks left (toward Nova coming from the left), 1 looks right
var _fish: Array[Vector2] = [] # piranha: where each fish swims inside the school


func setup(creature: String, at: Vector2, seed_value: int) -> void:
	kind = creature
	position = at
	_home = at
	_age = Art.hash01(seed_value) * 10.0
	_cycle = Art.hash01(seed_value + 7) * Balance.RAY_PERIOD        # rays do not all flash together
	if kind == "piranha":
		for i in 6:                                     # two loose rows of three, so every fish can be seen
			var jitter := Vector2(Art.hash01(seed_value + i) * 14.0 - 7.0, Art.hash01(seed_value + i + 20) * 10.0 - 5.0)
			var row := int(i / 3.0)
			_fish.append(Vector2((i % 3 - 1) * 34.0 + row * 16.0, row * 30.0 - 15.0) + jitter)


# ---- Behaviour ----

func _process(delta: float) -> void:
	_age += delta
	cooldown = maxf(0.0, cooldown - delta)
	if player:
		match kind:
			"piranha": _school(delta)
			"puffer": _puff(delta)
			"ray": _glide(delta)
	queue_redraw()


# The school drifts around its home, and darts at Nova when she is close (unless it just bit).
func _school(delta: float) -> void:
	var to_player := player.position - position
	var target := Vector2.ZERO
	if cooldown <= 0.0 and to_player.length() < Balance.PIRANHA_SENSE and player.state == Player.State.WATER:
		target = to_player.normalized() * Balance.PIRANHA_SPEED
	else:
		var wander := _home + Vector2(sin(_age * 0.6) * 90.0, sin(_age * 0.9) * 40.0)
		target = (wander - position).limit_length(90.0)
	_vel = _vel.lerp(target, 1.0 - exp(-4.0 * delta))
	position += _vel * delta
	if terrain:                                     # stay inside the water corridor
		position.y = clampf(position.y, maxf(terrain.ceiling_y(position.x), 0.0) + 40.0, terrain.floor_y(position.x) - 40.0)
	if absf(_vel.x) > 10.0:
		_facing = signf(_vel.x)


func _puff(delta: float) -> void:
	var near := player.position.distance_to(position) < Balance.PUFFER_SENSE
	puff = move_toward(puff, 1.0 if near else 0.0, delta * (5.0 if near else 0.7))
	position.y = _home.y + sin(_age * 1.3) * 10.0


func _glide(delta: float) -> void:
	_cycle = fposmod(_cycle + delta, Balance.RAY_PERIOD)
	var x := _home.x + sin(_age * 0.35) * 160.0
	_facing = -1.0 if cos(_age * 0.35) < 0.0 else 1.0
	position = Vector2(x, _home.y + sin(_age * 0.8) * 14.0)


func charging() -> bool:
	return kind == "ray" and _cycle >= Balance.RAY_PERIOD - Balance.RAY_DISCHARGE - Balance.RAY_CHARGE and not discharging()


func discharging() -> bool:
	return kind == "ray" and _cycle >= Balance.RAY_PERIOD - Balance.RAY_DISCHARGE


# Is Nova (at `at`) being hurt by this creature right now?
func touching(at: Vector2) -> bool:
	if cooldown > 0.0:
		return false
	var gap := at.distance_to(position) - Balance.PLAYER_RADIUS
	match kind:
		"puffer":
			return puff > 0.4 and gap < _puffer_radius() + 6.0      # a relaxed puffer is harmless
		"ray":
			return gap < BODY_RADIUS["ray"] or (discharging() and gap < Balance.RAY_FIELD)
	return gap < BODY_RADIUS[kind]


# How much this creature lights up the dark water (screen fraction, as Pip's light; 0 = none).
# Rays brighten while charging, so the warning shows even in the Trench; piranha eyes glow a little.
func light_radius() -> float:
	match kind:
		"ray":
			if discharging():
				return 0.22
			if charging():
				return 0.08 + 0.08 * (_cycle - (Balance.RAY_PERIOD - Balance.RAY_DISCHARGE - Balance.RAY_CHARGE)) / Balance.RAY_CHARGE
			return 0.07
		"piranha":
			return 0.06
	return 0.04


# Called by run.gd after it applied the hit. Piranhas scatter, the others just rest a moment.
func on_hit() -> void:
	cooldown = {"piranha": 2.5, "puffer": 0.8, "ray": 1.2}[kind]
	if kind == "piranha" and player:
		_vel = (position - player.position).normalized() * 420.0


# ---- Drawing ----

func _draw() -> void:
	match kind:
		"piranha": _draw_school()
		"puffer": _draw_puffer()
		"ray": _draw_ray()


func _draw_school() -> void:
	var hunting := _vel.length() > 200.0
	Art.glow(self, Vector2.ZERO, 90.0, Color("ff3a4a", 0.18 if hunting else 0.08))
	for i in _fish.size():
		var wobble := Vector2(sin(_age * 3.0 + i * 1.7) * 6.0, cos(_age * 2.4 + i) * 5.0)
		draw_set_transform(_fish[i] * 1.2 + wobble, 0.0, Vector2(-_facing * 1.5, 1.5))   # fish are drawn facing left
		_piranha(sin(_age * 14.0 + i) * (1.0 if hunting else 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# One piranha facing left: deep red back, orange belly, a jaw full of teeth and an angry eye.
func _piranha(wag: float) -> void:
	var body := PackedVector2Array([Vector2(-16, -2), Vector2(-8, -11), Vector2(6, -12), Vector2(16, -4), Vector2(18, 4), Vector2(8, 11), Vector2(-8, 9)])
	Art.shape(self, PackedVector2Array([Vector2(16, 0), Vector2(28, -9 + wag * 3.0), Vector2(28, 9 + wag * 3.0)]), Color("a01c2c"), Art.INK, 1.5)
	Art.shape(self, body, Color("c8283c"), Art.INK, 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 2), Vector2(14, 3), Vector2(8, 10), Vector2(-8, 8)]), Color("ff8a3a"))
	var teeth := PackedVector2Array()
	for k in 5:
		teeth.append(Vector2(-16 + k * 2.6, 2.0 + (2.5 if k % 2 == 0 else 0.0)))
	draw_polyline(teeth, Color.WHITE, 1.4, true)
	draw_circle(Vector2(-9, -4), 3.0, Color("ffd23f"))
	draw_circle(Vector2(-9.5, -4), 1.4, Art.INK)
	draw_line(Vector2(-13, -8), Vector2(-5, -6), Art.INK, 1.6, true)                 # angry brow


func _puffer_radius() -> float:
	return lerpf(20.0, 50.0, puff)


# A puffer facing left: a round yellow body with spots; spikes stand up as it puffs.
func _draw_puffer() -> void:
	var r := _puffer_radius()
	Art.glow(self, Vector2.ZERO, r * 2.6, Color(Art.AMBER, 0.12 + 0.25 * puff))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-_facing, 1.0))
	var fan := sin(_age * 9.0) * 4.0
	Art.shape(self, PackedVector2Array([Vector2(r - 4, 0), Vector2(r + 14, -9 + fan), Vector2(r + 14, 9 - fan)]), Color("e0a72a"), Art.INK, 1.5)   # tail
	var spike_length := lerpf(2.0, 13.0, puff)
	for i in 18:
		var a := TAU * i / 18.0 + 0.1
		var base := Vector2(cos(a), sin(a)) * (r - 2.0)
		var side := Vector2(-sin(a), cos(a)) * 3.0
		draw_colored_polygon(PackedVector2Array([base - side, base + Vector2(cos(a), sin(a)) * spike_length, base + side]), Color("fff2c0"))
	draw_circle(Vector2.ZERO, r + 1.5, Art.INK)
	draw_circle(Vector2.ZERO, r, Color("ffd23f").lerp(Color("ffb03a"), puff * 0.5))
	draw_circle(Vector2(0, r * 0.35), r * 0.6, Color("fff2c0", 0.55))               # pale belly
	for k in 5:
		draw_circle(Vector2(-r * 0.1 + Art.hash01(k) * r * 0.8, -r * 0.6 + Art.hash01(k + 5) * r * 0.5), 2.2 + r * 0.04, Color("7a5a12", 0.7))
	var eye := Vector2(-r * 0.45, -r * 0.25)
	draw_circle(eye, 5.0 + puff * 2.0, Color.WHITE)
	draw_circle(eye + Vector2(-1, 0), 2.6 + puff, Art.INK)
	draw_circle(Vector2(-r + 2.0, r * 0.15), 2.5 + puff * 1.5, Color("7a3a12"))      # a small round "o" mouth
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# An electric ray seen from above: a wide violet diamond with rippling wings and a long tail.
func _draw_ray() -> void:
	var charge := 0.0
	if charging():
		charge = (_cycle - (Balance.RAY_PERIOD - Balance.RAY_DISCHARGE - Balance.RAY_CHARGE)) / Balance.RAY_CHARGE
	if discharging():
		_draw_field()
		charge = 1.0
	var glow_color := Art.CYAN.lerp(Color.WHITE, charge * 0.5)
	Art.glow(self, Vector2.ZERO, 120.0 + 60.0 * charge, Color(glow_color, 0.12 + 0.4 * charge))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-_facing, 1.0))
	var flap := sin(_age * 3.0) * 8.0
	var tail_tip := Vector2(110, sin(_age * 2.0) * 10.0)
	draw_line(Vector2(30, 0), tail_tip, Art.INK, 5.0, true)
	draw_line(Vector2(30, 0), tail_tip, Color("8a7cff"), 3.0, true)
	# A round disc with wings swept back to the tips, a blunt snout in front, the tail behind.
	var body := PackedVector2Array([Vector2(-48, 0), Vector2(-42, -16), Vector2(-22, -40), Vector2(0, -62 - flap), Vector2(14, -52 - flap * 0.5),
			Vector2(24, -26), Vector2(32, 0), Vector2(24, 26), Vector2(14, 52 + flap * 0.5), Vector2(0, 62 + flap), Vector2(-22, 40), Vector2(-42, 16)])
	for side in [-1.0, 1.0]:                                              # small pelvic fins at the base of the tail
		Art.shape(self, PackedVector2Array([Vector2(26, 8 * side), Vector2(44, 20 * side), Vector2(40, 4 * side)]), Color("3a2f90"), Color(glow_color, 0.6), 1.5)
	Art.shape(self, body, Color("4a3fb0").lerp(Color("8a7cff"), charge * 0.6), Color(glow_color, 0.9), 2.5)
	for side in [-1.0, 1.0]:                                              # the two electric organs glow first
		Art.glow(self, Vector2(-6, 18 * side), 22.0, Color(Art.CYAN, 0.25 + 0.6 * charge))
		draw_circle(Vector2(-6, 18 * side), 7.0, Color(Art.CYAN, 0.35 + 0.6 * charge))
		draw_circle(Vector2(-30, 8 * side), 3.0, Art.ICE)                    # eyes
	if charge > 0.0 and not discharging():                               # crackle along the wings while charging
		for k in 3:
			_bolt(Vector2(14, -56 - flap), Vector2(-10 + randf() * 30.0, randf_range(-40, 40)), Color(Art.ICE, charge))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# The live field: a bright ring and lightning out to it.
func _draw_field() -> void:
	var r := Balance.RAY_FIELD
	draw_circle(Vector2.ZERO, r, Color(Art.CYAN, 0.10))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(Art.ICE, 0.9), 3.0, true)
	draw_arc(Vector2.ZERO, r - 8.0, 0.0, TAU, 48, Color(Art.CYAN, 0.5), 6.0, true)
	for k in 7:
		var a := TAU * k / 7.0 + randf() * 0.4
		_bolt(Vector2.ZERO, Vector2(cos(a), sin(a)) * r, Color(Art.ICE, 0.95))


# A jagged lightning line; it is random every frame, so it flickers.
func _bolt(from: Vector2, to: Vector2, color: Color) -> void:
	var points := PackedVector2Array([from])
	var side := (to - from).orthogonal().normalized()
	for i in range(1, 6):
		points.append(from.lerp(to, i / 6.0) + side * randf_range(-12.0, 12.0))
	points.append(to)
	draw_polyline(points, Color(Art.CYAN, color.a * 0.5), 5.0, true)
	draw_polyline(points, color, 2.0, true)
