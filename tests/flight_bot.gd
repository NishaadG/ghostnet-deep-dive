class_name FlightBot
extends RefCounted
# A simple "player" used by the smoke test and the tuning script:
# dive to build speed, pull up to glide, repeat. Not smart, just plausible.


var spawner: Spawner   # optional: when set, the bot also steers toward the nearest net ahead


func steer(p: Player) -> void:
	var clearance := p.terrain.floor_y(p.position.x) - p.position.y
	var target_deg := 8.0
	if p.state != Player.State.WATER:
		target_deg = 55.0                                  # dive into the water steeply
	elif clearance < 220.0:
		target_deg = -20.0                                 # too close to the floor: pull up
	elif p.vel.length() < 420.0 and clearance > 420.0:
		target_deg = 60.0                                  # slow and high: plunge for speed
	var net := _nearest_net_ahead(p)
	if net and p.state == Player.State.WATER:
		var to_net := net.position - p.position
		target_deg = clampf(rad_to_deg(to_net.angle()), -30.0, 70.0)
	p.tilt_input = clampf((deg_to_rad(target_deg) - p.angle) * 6.0, -1.0, 1.0)
	p.thrust_input = p.state == Player.State.WATER and p.vel.length() < 150.0


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
