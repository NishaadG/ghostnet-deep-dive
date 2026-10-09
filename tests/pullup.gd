extends Node

class OpenWater extends Terrain:
	func ceiling_y(_x: float) -> float:
		return -1.0e9

# Measures the pull-up: plunge at 60 deg, reach 600 px/s, then hold nose up. Prints height regained.
func _ready() -> void:
	var terrain := OpenWater.new()
	terrain.setup(1)
	terrain.points = PackedVector2Array([Vector2(-3000, 5000), Vector2(90000, 5000)])
	var p := Player.new()
	p.scripted = true
	p.start(Balance.stats_for({}), terrain)
	p.state = Player.State.WATER
	p.position = Vector2(0, 1000)
	p.angle = deg_to_rad(60)
	p.vel = Vector2.RIGHT.rotated(p.angle) * 600.0
	p.oxygen = 99
	var low := 0.0
	var line := ""
	for f in 240:
		p.tilt_input = -1.0
		p._physics_process(1.0 / 60.0)
		low = maxf(low, p.position.y)
		if f == 0: p.position.y = 1000.0
		if f % 30 == 29:
			line += "  t%.1f: y=%d v=%d" % [(f + 1) / 60.0, p.position.y, p.vel.length()]
	print("lowest y ", int(low), line)
	get_tree().quit()
