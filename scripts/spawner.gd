class_name Spawner
extends Node2D
# Fills the water ahead of Nova with nets, pickups and plastic, and reports touches.
# The Net Return upgrade works here: stats["net_density"] scales how many loose nets exist.

signal net_touched(net: Net)
signal pickup_touched(pickup: Pickup)

const SLICE := 600.0        # world is filled in slices this wide
const AHEAD := 3200.0
const BEHIND := 1800.0
const FIRST_X := 700.0      # keep the launch area clear

var terrain: Terrain
var stats: Dictionary
var rng := RandomNumberGenerator.new()
var nets: Array[Net] = []
var pickups: Array[Pickup] = []
var loose_net_x: Array[float] = []   # x of every loose net ever placed, for the results line
var _frontier := FIRST_X
var _scanned_to := 0.0


func setup(new_terrain: Terrain, new_stats: Dictionary, seed_value: int) -> void:
	terrain = new_terrain
	stats = new_stats
	rng.seed = seed_value


func update(player: Player) -> void:
	while _frontier < player.position.x + AHEAD:
		_spawn_nets(_frontier)
		_spawn_loose_pickups(_frontier)
		_frontier += SLICE
	_spawn_arcs()
	_check_touches(player)
	_remove_behind(player.position.x - BEHIND)


# "The fleet cut loose M nets" = loose nets placed along the stretch Nova travelled.
func loose_nets_up_to(x: float) -> int:
	var count := 0
	for net_x in loose_net_x:
		if net_x <= x:
			count += 1
	return count


# ---- Placement ----

func _spawn_nets(x0: float) -> void:
	var zone := Balance.zone_id_at(x0)
	if zone == "abyss":
		zone = "slope"
	var expected: float = Balance.NET_RATE[zone] * stats["net_density"]
	var count := int(expected) + (1 if rng.randf() < fmod(expected, 1.0) else 0)
	for i in count:
		var x := x0 + rng.randf() * SLICE
		var net := Net.new()
		net.setup(rng.randi() % 4, rng.randf() < Balance.NET_ANIMAL_CHANCE)
		var low := maxf(terrain.ceiling_y(x) + 120.0, 60.0)
		var high := terrain.floor_y(x) - 120.0
		net.position = Vector2(x, rng.randf_range(low, maxf(low, high)))
		add_child(net)
		nets.append(net)
		loose_net_x.append(x)


func _spawn_loose_pickups(x0: float) -> void:
	var x := x0 + rng.randf() * SLICE
	var roll := rng.randf()
	if roll < 0.12:
		_add_pickup("o2", Vector2(x, terrain.floor_y(x) - rng.randf_range(180, 300)))
	elif roll < 0.16:
		_add_pickup("fuel", Vector2(x, terrain.floor_y(x) - rng.randf_range(180, 300)))
	elif roll < 0.45:                                   # a small cluster of plastic
		var centre := Vector2(x, terrain.floor_y(x) - rng.randf_range(120, 280))
		for i in rng.randi_range(3, 5):
			_add_pickup("junk", centre + Vector2(rng.randf_range(-90, 90), rng.randf_range(-60, 60)))


# Pickups follow glide arcs: out past a ledge and down the drop, so good flying is rewarded.
func _spawn_arcs() -> void:
	var points := terrain.points
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		if a.x < _scanned_to:
			continue
		if b.x > _frontier:
			break
		_scanned_to = a.x + 1.0
		if a.x > 400.0 and b.y - a.y >= 100.0 and b.x - a.x <= 200.0 and rng.randf() < 0.7:
			_place_arc(a, b)


func _place_arc(lip: Vector2, base: Vector2) -> void:
	var count := clampi(int((base.y - lip.y) / 250.0) + 3, 3, 6)
	var o2_index := rng.randi_range(1, count - 2)
	var fuel_index := count - 1 if rng.randf() < 0.3 else -1
	for i in count:
		var t := (i + 1.0) / (count + 1.0)
		var x := lip.x + 60.0 + t * (base.x - lip.x + 450.0)
		var y := lerpf(lip.y - 90.0, base.y - 160.0, t)
		var kind := "junk"
		if i == o2_index:
			kind = "o2"
		elif i == fuel_index:
			kind = "fuel"
		_add_pickup(kind, Vector2(x, _inside_corridor(x, y)))


func _inside_corridor(x: float, y: float) -> float:
	var top := maxf(terrain.ceiling_y(x) + 70.0, 40.0)
	return clampf(y, top, maxf(top, terrain.floor_y(x) - 70.0))


func _add_pickup(kind: String, pos: Vector2) -> void:
	var pickup := Pickup.new()
	pickup.setup(kind)
	pickup.position = pos
	add_child(pickup)
	pickups.append(pickup)


# ---- Touching ----

func _check_touches(player: Player) -> void:
	var reach := Balance.PLAYER_RADIUS
	for net in nets:
		if not net.is_cut and net.position.distance_to(player.position) < net.radius + reach:
			net_touched.emit(net)
	for pickup in pickups:
		if pickup.collected:
			continue
		var gap := pickup.position.distance_to(player.position)
		# Pip's magnet pulls useful pickups (not plastic) toward Nova.
		if pickup.kind != "junk" and gap < stats["magnet_radius"]:
			pickup.position = pickup.position.move_toward(player.position, 500.0 / 60.0)
		if gap < pickup.radius + reach:
			pickup_touched.emit(pickup)


# Cut nets and collected pickups free themselves; everything else is freed once it is behind us.
func _remove_behind(x: float) -> void:
	var kept_nets: Array[Net] = []
	for net in nets:
		if net.is_cut:
			continue
		if net.position.x < x:
			net.queue_free()
		else:
			kept_nets.append(net)
	nets = kept_nets
	var kept_pickups: Array[Pickup] = []
	for pickup in pickups:
		if pickup.collected:
			continue
		if pickup.position.x < x:
			pickup.queue_free()
		else:
			kept_pickups.append(pickup)
	pickups = kept_pickups
