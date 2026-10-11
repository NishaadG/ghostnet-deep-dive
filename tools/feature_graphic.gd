extends Node
# The title scene without buttons, for the Google Play feature graphic (1024 x 500).
# Capture: godot --path . res://tools/feature_graphic.tscn --write-movie out.png --fixed-fps 30 --quit-after 60 -- real
# then crop to 1280 x 625 and scale to 1024 x 500 (README "Android" section).


func _ready() -> void:
	Game.save_enabled = false
	var title := Title.new()
	add_child(title)
	for child in title.get_children():
		if child is Button or child is Label:            # menu buttons, mode switch and the footer line
			child.visible = false
	# The title's own diver keeps swimming across; for a still picture place Nova and Pip by hand.
	for rig in title.find_children("*", "DiverRig", true, false):
		rig.visible = false
	var nova := DiverRig.new()
	nova.position = Vector2(300, 470)
	nova.body_scale = 2.4
	nova.rotation = -0.15
	nova.speed = 300.0
	add_child(nova)
	var pip := Pip.new()
	pip.position = Vector2(190, 390)
	pip.scale = Vector2(1.6, 1.6)
	add_child(pip)
