class_name StoryGallery
extends Control
# The STORY screen on the title menu: every cutscene in story order. Scenes seen in any save slot
# can be watched again; the rest show as locked until a dive reaches them.

signal scene_chosen(id: String)
signal back_pressed


func _ready() -> void:
	size = Vector2(1280, 720)
	var scene := MenuScene.new()
	scene.dim = 0.5
	scene.show_diver = false
	add_child(scene)
	var title := UiKit.label("THE STORY SO FAR", 44, true)
	title.position = Vector2(0, 40)
	title.size = Vector2(1280, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var gallery: Array = Game.settings["gallery"]
	for i in Story.ORDER.size():
		var id: String = Story.ORDER[i]
		var unlocked := id in gallery
		var text := "%d.  %s" % [i + 1, Story.title_of(id) if unlocked else "? ? ?"]
		var button := UiKit.button(text, Vector2(470, 52), Art.CYAN if unlocked else Art.ICE, false, 19)
		button.position = Vector2(150 + (i % 2) * 510, 130 + int(i / 2.0) * 68)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = not unlocked
		button.pressed.connect(func(): scene_chosen.emit(id))
		add_child(button)
	var hint := UiKit.label("Locked scenes unlock as your dives reach them.", 16, false, Color(Art.ICE, 0.7))
	hint.position = Vector2(0, 580)
	hint.size = Vector2(1280, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	var back := UiKit.button("BACK", Vector2(180, 50), Art.CYAN, true)
	back.position = Vector2(550, 630)
	back.pressed.connect(func(): back_pressed.emit())
	add_child(back)
