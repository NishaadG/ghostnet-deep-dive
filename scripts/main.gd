extends Node
# Screen switcher. Only one screen (a Node) is alive at a time.
# Milestone 1: just dive, show the result text, dive again.

var _screen: Node
var _waiting_for_confirm := false
var _result_label: Label


func _ready() -> void:
	start_run()


func start_run() -> void:
	_waiting_for_confirm = false
	var run := Run.new()
	run.finished.connect(_on_run_finished)
	_show(run)


func _on_run_finished(result: Dictionary) -> void:
	var layer := CanvasLayer.new()
	_result_label = Label.new()
	_result_label.position = Vector2(400, 250)
	_result_label.text = "Dive over (%s)\nDistance %d m   Depth %d m   Top speed %d\n\nPress Enter to dive again" % [
		result["reason"], result["distance_m"], result["max_depth_m"], result["top_speed"]]
	layer.add_child(_result_label)
	_screen.add_child(layer)
	_waiting_for_confirm = true


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_for_confirm and event.is_action_pressed("confirm"):
		start_run()


func _show(screen: Node) -> void:
	if _screen:
		_screen.queue_free()
	_screen = screen
	add_child(screen)
