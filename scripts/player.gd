class_name Player
extends Node2D
# Nova's body and flight model. Plain arcade physics, no physics engine:
# we move the position ourselves and test it against the terrain height lookup.
# Besides flying she reports tricks (flips, loops, grinds) as signals; style_score.gd scores them.

signal launched
signal splashed(pos: Vector2, loss: float)
signal landed(air_time: float, flips: int, clean: bool, entry_deg: float)   # back in the water after being airborne
signal flipped                                                                # one full rotation completed in the air
signal looped                                                                 # a loop completed underwater
signal grind_ended(seconds: float)                                            # a long skim along the seabed ended
signal hit_floor(into_speed: float)
signal hit_ceiling
signal ended(reason: String)

enum State { RAMP, AIR, WATER, DONE }

var stats: Dictionary
var terrain: Terrain
var state := State.RAMP
var vel := Vector2.ZERO
var angle := 0.0               # facing: 0 = right, positive = nose down
var oxygen := 0.0
var fuel := 0.0
var thrusting := false
var touching_rock := false     # true on a frame where she touched the floor or ceiling
var looping := false

# Input is read into these two fields; tests and the touch UI can fill them instead.
var scripted := false
var tilt_input := 0.0          # -1 nose up, +1 nose down
var thrust_input := false

var rig: DiverRig
var _ramp_t := 0.0
var _ramp_length := 1.0
var _rest_timer := 0.0
var _ceiling_cooldown := 0.0
var _floor_hit_cooldown := 0.0
var _air_time := 0.0
var _air_rotation := 0.0
var _flips_done := 0
var _loop_charge := 0.0
var _loop_turned := 0.0
var _grind_time := 0.0


func start(new_stats: Dictionary, new_terrain: Terrain) -> void:
	stats = new_stats
	terrain = new_terrain
	oxygen = stats["max_oxygen"]
	fuel = stats["max_fuel"]
	var level: int = stats["ramp_level"]
	position = Balance.ramp_point(level, 0.0)
	_ramp_length = 0.0                                   # rough curve length: sum of short chords
	for i in 20:
		_ramp_length += Balance.ramp_point(level, i / 20.0).distance_to(Balance.ramp_point(level, (i + 1) / 20.0))
	angle = Balance.ramp_direction(level, 0.0).angle()
	rotation = angle
	rig = DiverRig.new()
	rig.tiers = {"craft": stats["craft_tier"], "booster": stats["booster_tier"], "cutter": stats["cutter_tier"]}
	add_child(rig)


func _physics_process(delta: float) -> void:
	if state == State.DONE:
		return
	if not scripted:
		tilt_input = Input.get_axis("tilt_up", "tilt_down")
		thrust_input = Input.is_action_pressed("thrust")
	_ceiling_cooldown = maxf(0.0, _ceiling_cooldown - delta)
	_floor_hit_cooldown = maxf(0.0, _floor_hit_cooldown - delta)
	match state:
		State.RAMP:
			_slide_down_ramp(delta)
		State.AIR:
			_fly_through_air(delta)
		State.WATER:
			_swim(delta)
	rotation = angle
	rig.thrust = 1.0 if thrusting else 0.0
	rig.speed = vel.length()


# Down the ramp with constant acceleration, then off the ski-jump lip heading slightly upward.
func _slide_down_ramp(delta: float) -> void:
	var level: int = stats["ramp_level"]
	var speed: float = stats["launch_speed"] * maxf(0.6, sqrt(_ramp_t))
	_ramp_t += speed * delta / _ramp_length
	if _ramp_t < 1.0:
		position = Balance.ramp_point(level, _ramp_t)
		angle = Balance.ramp_direction(level, _ramp_t).angle()
		return
	position = Balance.RAMP_END
	angle = Balance.ramp_direction(level, 1.0).angle()
	vel = Vector2.RIGHT.rotated(angle) * stats["launch_speed"]
	_begin_air()
	launched.emit()


func _begin_air() -> void:
	state = State.AIR
	_air_time = 0.0
	_air_rotation = 0.0
	_flips_done = 0


# In the air she can spin freely: full flips score, but she must land nose-first to keep them.
func _fly_through_air(delta: float) -> void:
	var turn := tilt_input * Balance.AIR_TILT_RATE * delta
	angle += turn
	_air_rotation += turn
	if absf(_air_rotation) >= TAU * (_flips_done + 1):
		_flips_done += 1
		flipped.emit()
	_air_time += delta
	vel.y += Balance.AIR_GRAVITY * delta
	position += vel * delta
	if position.y >= 0.0:
		_enter_water()


# Entering the water: a steep nose-first entry keeps all speed, a flat or backwards one loses up to 40%.
func _enter_water() -> void:
	var entry := wrapf(angle, -PI, PI)
	var deg := rad_to_deg(entry)
	var flatness := 1.0
	if deg <= 90.0:
		flatness = 1.0 - clampf((deg - Balance.ENTRY_FLAT_DEG) / (Balance.ENTRY_STEEP_DEG - Balance.ENTRY_FLAT_DEG), 0.0, 1.0)
	var loss: float = Balance.ENTRY_MAX_LOSS * flatness * stats["entry_loss_mult"]
	vel *= 1.0 - loss
	state = State.WATER
	angle = clampf(entry, Balance.ANGLE_MIN, Balance.ANGLE_MAX)
	var clean := deg >= 20.0 and deg <= 85.0               # nose-first: flips and airtime count
	landed.emit(_air_time, _flips_done, clean, deg)
	splashed.emit(position, loss)


# Underwater the nose has a limited range, except during a loop (see _try_loop).
func _tilt(delta: float) -> void:
	if looping:
		return
	var wanted := angle + tilt_input * Balance.TILT_RATE * delta
	_try_loop(wanted, delta)
	angle = clampf(wanted, Balance.ANGLE_MIN, Balance.ANGLE_MAX)


# Hold nose-up against the limit while fast and with room above and below, and she commits to a loop.
func _try_loop(wanted: float, delta: float) -> void:
	var at_limit := tilt_input < 0.0 and wanted <= Balance.ANGLE_MIN and vel.length() >= Balance.LOOP_MIN_SPEED
	if not (at_limit and _has_room_to_loop()):
		_loop_charge = 0.0
		return
	_loop_charge += delta
	if _loop_charge >= Balance.LOOP_CHARGE:
		looping = true
		_loop_turned = 0.0
		_loop_charge = 0.0


func _has_room_to_loop() -> bool:
	var radius := vel.length() / Balance.LOOP_RATE          # faster loops are bigger and need more room
	var needed := radius * 1.5 + 60.0
	var below := terrain.floor_y(position.x) - position.y
	var above := position.y - maxf(terrain.ceiling_y(position.x), 0.0)
	return below > needed and above > needed


# The core model. Read it top to bottom: weight, wing, drag, thrust, move, collide.
func _swim(delta: float) -> void:
	_tilt(delta)
	oxygen -= delta
	if Debug.is_on("oxygen"):
		oxygen = stats["max_oxygen"]
	vel.y += Balance.GRAVITY * stats["ballast_mult"] * delta                 # sinking weight
	if looping:
		_loop_step(delta)
	else:
		# The wing slowly turns the direction of travel toward the nose. This is "lift".
		var max_turn: float = Balance.WING_TURN * stats["wing_mult"] * delta
		vel = vel.rotated(clampf(angle_difference(vel.angle(), angle), -max_turn, max_turn))
	# Drag grows with speed, and more when the nose and the motion disagree.
	var misalign := absf(angle_difference(vel.angle(), angle))
	var drag: float = (Balance.DRAG + Balance.DRAG_MISALIGN * misalign) * stats["drag_mult"]
	vel -= vel * drag * vel.length() * delta
	thrusting = thrust_input and fuel > 0.0
	if thrusting:
		fuel = stats["max_fuel"] if Debug.is_on("fuel") else fuel - delta
		vel += Vector2.RIGHT.rotated(angle) * Balance.THRUST * stats["thrust_mult"] * delta
	position += vel * delta
	if position.y < 0.0:                                                     # breached the surface
		_begin_air()
		return
	_collide_with_terrain(delta)
	if oxygen <= 0.0:
		oxygen = 0.0
		finish("oxygen")


# During a loop the nose and the motion turn together at a fixed rate, so the path is a tight circle.
func _loop_step(delta: float) -> void:
	var turn := Balance.LOOP_RATE * delta
	angle -= turn
	vel = vel.rotated(-turn)
	_loop_turned += turn
	if _loop_turned >= TAU:
		looping = false
		angle = wrapf(angle, -PI, PI)
		angle = clampf(angle, Balance.ANGLE_MIN, Balance.ANGLE_MAX)
		looped.emit()


func _collide_with_terrain(delta: float) -> void:
	var r := Balance.PLAYER_RADIUS
	var on_floor := false
	var grazing := false
	touching_rock = false
	var floor_y := terrain.floor_y(position.x)
	if position.y + r > floor_y:
		on_floor = true
		touching_rock = true
		# Surface normal from the local slope: tangent is (1, slope), normal points up and out.
		var slope := (terrain.floor_y(position.x + 6.0) - terrain.floor_y(position.x - 6.0)) / 12.0
		var normal := Vector2(slope, -1.0).normalized()
		var into_speed := -vel.dot(normal)
		if into_speed > Balance.CRASH_SPEED and not Debug.is_on("god"):
			finish("crash")
			return
		if into_speed > 0.0:
			vel += normal * into_speed                     # remove the part of velocity pointing into rock
			if into_speed > 120.0 and _floor_hit_cooldown == 0.0:
				hit_floor.emit(into_speed)
				_floor_hit_cooldown = 0.4
		vel *= 1.0 - Balance.FLOOR_FRICTION * delta        # skimming scrapes speed instead of stopping dead
		position.y = floor_y - r
		grazing = vel.length() > Balance.GRIND_MIN_SPEED
	var ceiling_y := terrain.ceiling_y(position.x)
	if ceiling_y > 0.0 and position.y - r < ceiling_y:
		touching_rock = true
		position.y = ceiling_y + r
		if vel.y < 0.0:
			vel.y = 40.0
			if _ceiling_cooldown == 0.0:
				vel *= Balance.CEILING_KEEP
				_ceiling_cooldown = Balance.CEILING_COOLDOWN
				hit_ceiling.emit()
	_track_grind(grazing, delta)
	if on_floor and vel.length() < Balance.REST_SPEED:
		_rest_timer += delta
		if _rest_timer >= Balance.REST_TIME and not Debug.is_on("god"):
			finish("rest")
	else:
		_rest_timer = 0.0


# A grind is an unbroken skim along the seabed at speed; it scores when it ends.
func _track_grind(grazing: bool, delta: float) -> void:
	if grazing:
		_grind_time += delta
		return
	if _grind_time >= Balance.GRIND_MIN_TIME:
		grind_ended.emit(_grind_time)
	_grind_time = 0.0


func add_oxygen(seconds: float) -> void:
	oxygen = minf(oxygen + seconds, stats["max_oxygen"])


func add_fuel(fraction_of_tank: float) -> void:
	fuel = minf(fuel + fraction_of_tank * stats["max_fuel"], stats["max_fuel"])


func finish(reason: String) -> void:
	if state == State.DONE:
		return
	if _grind_time >= Balance.GRIND_MIN_TIME and reason != "crash":
		grind_ended.emit(_grind_time)
	_grind_time = 0.0
	state = State.DONE
	thrusting = false
	looping = false
	ended.emit(reason)
