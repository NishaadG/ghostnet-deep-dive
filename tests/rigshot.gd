extends Node2D
# Draws the diver with every gear tier so the art can be inspected: godot --path . res://tests/rigshot.tscn --write-movie ...
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0a3c5a")
	bg.size = Vector2(1280, 720)
	add_child(bg)
	for tier in 6:
		var rig := DiverRig.new()
		rig.tiers = {"craft": tier, "booster": tier, "cutter": tier}
		rig.thrust = 1.0
		rig.speed = 400.0
		rig.body_scale = 1.5
		rig.position = Vector2(110 + (tier % 3) * 410, 190 + (tier / 3) * 330)
		add_child(rig)
		var label := Label.new()
		label.text = "%s / %s / %s" % [Balance.GEAR_NAMES["craft"][tier], Balance.GEAR_NAMES["booster"][tier], Balance.GEAR_NAMES["cutter"][tier]]
		label.position = rig.position + Vector2(-80, 100)
		add_child(label)
