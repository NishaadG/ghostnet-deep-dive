class_name FlightBot
extends RefCounted
# A simple "player" used by the smoke test and the tuning script:
# dive to build speed, pull up to glide, repeat. Not smart, just plausible.


func steer(p: Player) -> void:
	var clearance := p.terrain.floor_y(p.position.x) - p.position.y
	var target_deg := 8.0
	if p.state != Player.State.WATER:
		target_deg = 55.0                                  # dive into the water steeply
	elif clearance < 220.0:
		target_deg = -20.0                                 # too close to the floor: pull up
	elif p.vel.length() < 420.0 and clearance > 420.0:
		target_deg = 60.0                                  # slow and high: plunge for speed
	p.tilt_input = clampf((deg_to_rad(target_deg) - p.angle) * 6.0, -1.0, 1.0)
	p.thrust_input = p.state == Player.State.WATER and p.vel.length() < 150.0
