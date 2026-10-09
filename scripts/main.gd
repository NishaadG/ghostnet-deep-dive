extends Node
# Screen switcher. Only one screen (a Node) is alive at a time.
# Flow: Title -> Save slots -> (intro cards) -> Workshop -> Run -> Results -> Workshop,
# with the ending cards between Run and Results when the Lumen is freed.

var _screen: Node
var _overlay: Node          # settings or pause menu on top of the current screen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # so the pause menu works while the dive is paused
	show_title()


func show_title() -> void:
	var title := Title.new()
	title.play_pressed.connect(show_slots)
	title.continue_pressed.connect(func(slot: int): _begin(slot, false))
	title.settings_pressed.connect(_open_settings)
	title.quit_pressed.connect(func(): get_tree().quit())
	_show(title)


func show_slots() -> void:
	var slots := SlotSelect.new()
	slots.slot_chosen.connect(_begin)
	slots.back_pressed.connect(show_title)
	_show(slots)


func _begin(slot: int, is_new: bool) -> void:
	if is_new:
		Game.new_game(slot)
	else:
		Game.continue_game(slot)
	Game.settings["last_slot"] = slot
	Game.save_settings()
	if is_new:
		show_cards(StoryCards.INTRO, show_workshop)
	else:
		show_workshop()


func show_cards(lines: Array, then: Callable) -> void:
	var cards := StoryCards.new()
	cards.setup(lines)
	cards.finished.connect(then)
	_show(cards)


func show_workshop() -> void:
	var workshop := Workshop.new()
	workshop.dive_pressed.connect(start_run)
	workshop.menu_pressed.connect(show_title)
	_show(workshop)


func start_run() -> void:
	var run := Run.new()
	run.process_mode = Node.PROCESS_MODE_PAUSABLE
	run.finished.connect(_on_run_finished)
	_show(run)


func _on_run_finished(result: Dictionary) -> void:
	Engine.time_scale = 1.0
	Game.bank_run(result)
	if result["lumen_freed"]:
		show_cards(StoryCards.ENDING, func(): show_results(result))
	else:
		show_results(result)


func show_results(result: Dictionary) -> void:
	var results := Results.new()
	results.result = result
	results.continue_pressed.connect(show_workshop)
	_show(results)


# ---- Overlays: settings (anywhere) and pause (during a dive) ----

func _open_settings() -> void:
	_close_overlay()
	var panel := SettingsPanel.new()
	panel.closed.connect(_close_overlay)
	_overlay = panel
	add_child(panel)


func _open_pause() -> void:
	get_tree().paused = true
	var menu := PauseMenu.new()
	menu.resume_pressed.connect(_resume)
	menu.settings_pressed.connect(func():
		_close_overlay()
		var panel := SettingsPanel.new()
		panel.process_mode = Node.PROCESS_MODE_ALWAYS
		panel.closed.connect(_open_pause)
		_overlay = panel
		add_child(panel))
	menu.quit_pressed.connect(func():
		_resume()
		Engine.time_scale = 1.0
		show_workshop())
	_overlay = menu
	add_child(menu)


func _resume() -> void:
	_close_overlay()
	get_tree().paused = false


func _close_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _screen is Run and _overlay == null and not (_screen as Run).ended:
		_open_pause()


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
	if _screen is Workshop:
		show_workshop()              # rebuild so the new numbers show up


func _show(screen: Node) -> void:
	_close_overlay()
	if _screen:
		_screen.queue_free()
	_screen = screen
	add_child(screen)
