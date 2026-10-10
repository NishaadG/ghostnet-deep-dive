extends Node
# Headless check of the story: every beat names a known set, action, sound and speaker, and every
# scene plays from its first beat to `finished` without errors. Uses throwaway saves.
# Run: godot --headless --path . res://tests/cutscenes.tscn

var failures: Array[String] = []


func _ready() -> void:
	Game.save_enabled = false
	Game.save_dir = "user://test_"
	Game.new_game(1)
	for id in Story.ORDER:
		if not Story.SCENES.has(id):
			failures.append("ORDER lists a missing scene: %s" % id)
	for id in Story.SCENES:
		if not id in Story.ORDER:
			failures.append("scene missing from the gallery ORDER: %s" % id)
		for beat in Story.beats_of(id):
			_check_beat(id, beat)
	for id in Story.ORDER:
		await _play(id)
	for f in failures:
		printerr("CUTSCENES FAIL: ", f)
	print("CUTSCENES %s  (%d scenes)" % ["FAIL" if failures else "OK", Story.ORDER.size()])
	get_tree().quit(1 if failures else 0)


func _check_beat(id: String, beat: Dictionary) -> void:
	if beat.has("set") and not beat["set"] in CutsceneStage.SETS:
		failures.append("%s: unknown set %s" % [id, beat["set"]])
	var actions: Variant = beat.get("act", [])
	for action in (actions if actions is Array else [actions]):
		if not action in CutsceneStage.ACTIONS:
			failures.append("%s: unknown action %s" % [id, action])
	if beat.has("sfx") and not beat["sfx"] in Audio.ONE_SHOTS:
		failures.append("%s: unknown sound %s" % [id, beat["sfx"]])
	if beat.has("say") and not Story.SPEAKERS.has(beat.get("who", "")):
		failures.append("%s: unknown speaker %s" % [id, beat.get("who", "")])
	if not (beat.has("say") or beat.has("cap") or beat.has("wait")):
		failures.append("%s: a beat with no text needs a wait" % id)


# Click through a scene like an impatient player: one press finishes the line, the next moves on.
func _play(id: String) -> void:
	var cutscene := Cutscene.new()
	cutscene.setup(id)
	var done := [false]
	cutscene.finished.connect(func(): done[0] = true)
	add_child(cutscene)
	var frames := 0
	while not done[0] and frames < 3000:
		await get_tree().process_frame
		frames += 1
		if frames % 4 == 0:
			cutscene.advance()
	if not done[0]:
		failures.append("%s did not finish" % id)
	cutscene.queue_free()
	await get_tree().process_frame
