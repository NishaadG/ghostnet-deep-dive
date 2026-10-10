extends Node
# Writes every spoken line (Story.voice_lines) to tools/voice_lines.json for tools/make_voices.py.
# Run: godot --headless --path . res://tools/voice_lines.tscn


func _ready() -> void:
	var path := ProjectSettings.globalize_path("res://tools/voice_lines.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(Story.voice_lines(), "\t"))
	file.close()
	print("wrote %d lines to %s" % [Story.voice_lines().size(), path])
	get_tree().quit()
