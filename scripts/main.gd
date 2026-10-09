extends Node
# Screen switcher. Only one screen (a Node) is alive at a time.
# Flow: Dock -> Run -> Results -> Dock. (Title and story cards join in milestones 4 and 5.)

var _screen: Node


func _ready() -> void:
	show_dock()


func show_dock() -> void:
	var dock := Dock.new()
	dock.dive_pressed.connect(start_run)
	_show(dock)


func start_run() -> void:
	var run := Run.new()
	run.finished.connect(_on_run_finished)
	_show(run)


func _on_run_finished(result: Dictionary) -> void:
	Game.bank_run(result)
	var results := Results.new()
	results.result = result
	results.continue_pressed.connect(show_dock)
	_show(results)


# Debug keys, also live in the web build (listed in the README).
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_F1: Game.debug_reset()
		KEY_F2: Game.debug_add_tags()
		KEY_F3: Game.debug_mid_save()
		KEY_F4: Game.debug_unlock_endless()
		_: return
	if _screen is Dock:
		show_dock()              # rebuild so the new numbers show up


func _show(screen: Node) -> void:
	if _screen:
		_screen.queue_free()
	_screen = screen
	add_child(screen)
