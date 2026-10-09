class_name Player
extends Node2D
# Nova's body and flight model. Plain arcade physics, no physics engine:
# we move the position ourselves and test it against the terrain height lookup.

signal splashed(pos: Vector2, loss: float)
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

# Input is read into these two fields; tests and the touch UI can fill them instead.
var scripted := false
var tilt_input := 0.0          # -1 nose up, +1 nose down
var thrust_input := false

var _ramp_t := 0.0
var _rest_timer := 0.0
var _ceiling_cooldown := 0.0
var _floor_hit_cooldown := 0.0


func start(new_stats: Dictionary, new_terrain: Terrain) -> void:
	stats = new_stats
	terrain = new_terrain
	oxygen = stats["max_oxygen"]
	fuel = stats["max_fuel"]
	position = Balance.RAMP_START
	angle = (Balance.RAMP_END - Balance.RAMP_START).angle()
	rotation = angle


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
	queue_redraw()


# Constant acceleration down the ramp: speed grows with the square root of progress.
func _slide_down_ramp(delta: float) -> void:
	var length := Balance.RAMP_START.distance_to(Balance.RAMP_END)
	var speed: float = stats["launch_speed"] * maxf(0.25, sqrt(_ramp_t))
	_ramp_t += speed * delta / length
	if _ramp_t < 1.0:
		position = Balance.RAMP_START.lerp(Balance.RAMP_END, _ramp_t)
		return
	position = Balance.RAMP_END
	vel = Vector2.RIGHT.rotated(angle) * stats["launch_speed"]
	state = State.AIR


# In the air the player can only tilt: a steep nose-down entry keeps speed.
func _fly_through_air(delta: float) -> void:
	_tilt(delta)
	vel.y += Balance.AIR_GRAVITY * delta
	position += vel * delta
	if position.y >= 0.0:
		_enter_water()


func _enter_water() -> void:
	var steepness := (rad_to_deg(angle) - Balance.ENTRY_FLAT_DEG) / (Balance.ENTRY_STEEP_DEG - Balance.ENTRY_FLAT_DEG)
	var flatness := 1.0 - clampf(steepness, 0.0, 1.0)
	var loss: float = Balance.ENTRY_MAX_LOSS * flatness * stats["entry_loss_mult"]
	vel *= 1.0 - loss
	state = State.WATER
	splashed.emit(position, loss)


func _tilt(delta: float) -> void:
	angle = clampf(angle + tilt_input * Balance.TILT_RATE * delta, Balance.ANGLE_MIN, Balance.ANGLE_MAX)


# The core model. Read it top to bottom: weight, wing, drag, thrust, move, collide.
func _swim(delta: float) -> void:
	_tilt(delta)
	oxygen -= delta
	vel.y += Balance.GRAVITY * stats["ballast_mult"] * delta                 # sinking weight
	# The wing slowly turns the direction of travel toward the nose. This is "lift".
	var max_turn: float = Balance.WING_TURN * stats["wing_mult"] * delta
	vel = vel.rotated(clampf(angle_difference(vel.angle(), angle), -max_turn, max_turn))
	# Drag grows with speed, and more when the nose and the motion disagree.
	var misalign := absf(angle_difference(vel.angle(), angle))
	var drag: float = (Balance.DRAG + Balance.DRAG_MISALIGN * misalign) * stats["drag_mult"]
	vel -= vel * drag * vel.length() * delta
	thrusting = thrust_input and fuel > 0.0
	if thrusting:
		fuel -= delta
		vel += Vector2.RIGHT.rotated(angle) * Balance.THRUST * stats["thrust_mult"] * delta
	position += vel * delta
	if position.y < 0.0:                                                     # breached the surface
		state = State.AIR
		return
	_collide_with_terrain(delta)
	if oxygen <= 0.0:
		oxygen = 0.0
		finish("oxygen")


func _collide_with_terrain(delta: float) -> void:
	var r := Balance.PLAYER_RADIUS
	var on_floor := false
	var floor_y := terrain.floor_y(position.x)
	if position.y + r > floor_y:
		on_floor = true
		# Surface normal from the local slope: tangent is (1, slope), normal points up and out.
		var slope := (terrain.floor_y(position.x + 6.0) - terrain.floor_y(position.x - 6.0)) / 12.0
		var normal := Vector2(slope, -1.0).normalized()
		var into_speed := -vel.dot(normal)
		if into_speed > Balance.CRASH_SPEED:
			finish("crash")
			return
		if into_speed > 0.0:
			vel += normal * into_speed                     # remove the part of velocity pointing into rock
			if into_speed > 120.0 and _floor_hit_cooldown == 0.0:
				hit_floor.emit(into_speed)
				_floor_hit_cooldown = 0.4
		vel *= 1.0 - Balance.FLOOR_FRICTION * delta        # skimming scrapes speed instead of stopping dead
		position.y = floor_y - r
	var ceiling_y := terrain.ceiling_y(position.x)
	if ceiling_y > 0.0 and position.y - r < ceiling_y:
		position.y = ceiling_y + r
		if vel.y < 0.0:
			vel.y = 40.0
			if _ceiling_cooldown == 0.0:
				vel *= Balance.CEILING_KEEP
				_ceiling_cooldown = Balance.CEILING_COOLDOWN
				hit_ceiling.emit()
	if on_floor and vel.length() < Balance.REST_SPEED:
		_rest_timer += delta
		if _rest_timer >= Balance.REST_TIME:
			finish("rest")
	else:
		_rest_timer = 0.0


func add_oxygen(seconds: float) -> void:
	oxygen = minf(oxygen + seconds, stats["max_oxygen"])


func add_fuel(fraction_of_tank: float) -> void:
	fuel = minf(fuel + fraction_of_tank * stats["max_fuel"], stats["max_fuel"])


func finish(reason: String) -> void:
	if state == State.DONE:
		return
	state = State.DONE
	thrusting = false
	ended.emit(reason)


# Grey-box body, replaced by the sprite rig in milestone 5.
func _draw() -> void:
	draw_rect(Rect2(-34, -13, 68, 26), Color(0.95, 0.6, 0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(34, -13), Vector2(52, 0), Vector2(34, 13)]), Color.WHITE)
	if thrusting:
		draw_colored_polygon(PackedVector2Array([Vector2(-34, -8), Vector2(-70, 0), Vector2(-34, 8)]), Color(1, 0.9, 0.3))
