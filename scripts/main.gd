extends Node
# Screen switcher. Only one screen (a Node) is alive at a time.
# Flow so far: Run -> Results -> Run. The dock joins in milestone 3.

var _screen: Node


func _ready() -> void:
	start_run()


func start_run() -> void:
	var run := Run.new()
	run.finished.connect(_on_run_finished)
	_show(run)


func _on_run_finished(result: Dictionary) -> void:
	Game.bank_run(result)
	var results := Results.new()
	results.result = result
	results.continue_pressed.connect(start_run)
	_show(results)


func _show(screen: Node) -> void:
	if _screen:
		_screen.queue_free()
	_screen = screen
	add_child(screen)
