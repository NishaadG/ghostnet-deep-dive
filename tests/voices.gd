extends Node
# Headless check of the voice-over wiring: every spoken line has a unique id, the clips that exist
# load and play, missing clips are silent, and a cutscene line types at the pace of its voice.
# Run: godot --headless --path . res://tests/voices.tscn

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _ready() -> void:
	Game.save_enabled = false
	var lines := Story.voice_lines()
	var ids := {}
	for line in lines:
		check(not ids.has(line["id"]), "voice id %s is unique" % line["id"])
		ids[line["id"]] = true
		check(Story.SPEAKERS.has(line["who"]) or line["who"] == "narrator", "speaker %s is known" % line["who"])
	for scene_id in Story.ORDER:                          # every line of text in a scene has a voice id
		var beats := Story.beats_of(scene_id)
		for i in beats.size():
			var beat: Dictionary = beats[i]
			var silent: bool = beat.has("say") and String(beat["say"]).replace(".", "").strip_edges() == ""
			if (beat.has("cap") or beat.has("say")) and not silent:
				check(ids.has(Story.beat_voice(scene_id, i)), "%s beat %d has a voice line" % [scene_id, i])
	check(not Audio.has_voice("no_such_line"), "a missing clip is reported missing")
	Audio.play_voice("no_such_line")                     # must not crash
	var found := 0
	for line in lines:
		if Audio.has_voice(line["id"]):
			found += 1
			check(Audio.voice_length(line["id"]) > 0.3, "clip %s has sound" % line["id"])
	# A cutscene line with a clip types at the voice's pace.
	var first := Story.beat_voice("intro", 0)
	var cutscene := Cutscene.new()
	cutscene.setup("intro")
	add_child(cutscene)
	if Audio.has_voice(first):
		check(absf(cutscene._speed - Cutscene.TYPE_SPEED) > 0.01 or Audio.voice_length(first) <= 0.0, "typing follows the voice")
	print("clips present: %d of %d" % [found, lines.size()])
	for f in failures:
		printerr("VOICES FAIL: ", f)
	print("VOICES %s" % ("FAIL" if failures else "OK"))
	get_tree().quit(1 if failures else 0)
