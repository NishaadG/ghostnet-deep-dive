class_name FlightBot
extends RefCounted
# A simple "player" used by the tests: dive to build speed, pull up to glide, repeat.
# `clumsiness` (0 = perfect, 1 = very sloppy) makes it fly like a person: it wanders off its
# target angle, reacts late and often misses nets. Used by tests/economy.gd to tune the economy.

var spawner: Spawner         # optional: when set, the bot steers toward the nearest net ahead
var clumsiness := 0.0
var rng := RandomNumberGenerator.new()
var _wander := 0.0           # current error in degrees
var _wander_timer := 0.0
var _hunt := true
var _hunt_timer := 0.0


func steer(p: Player, delta := 1.0 / 60.0) -> void:
	_update_mistakes(delta)
	# Look ahead along the corridor: the highest floor and the lowest ceiling within about a second.
	var reach := clampf(p.vel.length() * 1.1, 250.0, 1400.0)
	var floor_ahead := p.terrain.floor_y(p.position.x)
	var ceiling_ahead := -1.0e9
	for k in range(0, 9):
		var x := p.position.x + reach * k / 8.0
		floor_ahead = minf(floor_ahead, p.terrain.floor_y(x))
		ceiling_ahead = maxf(ceiling_ahead, p.terrain.ceiling_y(x))
	var clearance := floor_ahead - p.position.y
	var target_deg := 8.0
	if p.state != Player.State.WATER:
		target_deg = 55.0                                  # dive into the water steeply
	elif clearance < 230.0 + maxf(p.vel.y, 0.0):
		target_deg = -30.0                                 # floor coming up (or a wall rising): pull up early
	elif p.position.y < ceiling_ahead + 120.0 and ceiling_ahead > 0.0:
		target_deg = 35.0                                  # a ceiling is dropping ahead: go down with it
	elif p.vel.length() < 420.0 and clearance > 700.0:
		target_deg = 60.0                                  # slow and high: plunge for speed
	var net := _nearest_net_ahead(p)
	if net and p.state == Player.State.WATER and _hunt and clearance > 330.0:
		target_deg = clampf(rad_to_deg((net.position - p.position).angle()), -30.0, 70.0)
	target_deg += _wander
	var gain := 6.0 * (1.0 - 0.7 * clumsiness)             # a sloppy pilot turns the nose more slowly
	p.tilt_input = clampf((deg_to_rad(target_deg) - p.angle) * gain, -1.0, 1.0)
	p.thrust_input = p.state == Player.State.WATER and p.vel.length() < 150.0 and rng.randf() > clumsiness * 0.5


func _update_mistakes(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander = rng.randfn(0.0, 22.0 * clumsiness)
		_wander_timer = rng.randf_range(0.3, 1.0)
	_hunt_timer -= delta
	if _hunt_timer <= 0.0:
		_hunt = rng.randf() > clumsiness * 0.8             # sloppy pilots often ignore nets
		_hunt_timer = rng.randf_range(0.5, 2.0)


func _nearest_net_ahead(p: Player) -> Net:
	if spawner == null:
		return null
	var best: Net = null
	for net in spawner.nets:
		if net.is_cut or net.position.x < p.position.x or net.position.x > p.position.x + 900.0:
			continue
		if best == null or net.position.x < best.position.x:
			best = net
	return best
