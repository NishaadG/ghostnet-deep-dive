extends Node
# Screen switcher. Only one screen (a Node) is alive at a time.
# Flow: Title -> Save slots -> (intro cutscene) -> Workshop -> Run -> Results -> Workshop.
# Cutscenes (see Story): the intro on a new game; a wall's meeting scene pauses the dive the
# first time it comes into view; scenes for torn walls and the ending play between Run and Results.

var _screen: Node
var _overlay: Node          # settings or pause menu on top of the current screen
var _rotate_notice: Control # shown on a phone held upright: the game is landscape only


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # so the pause menu works while the dive is paused
	Debug.main = self
	_build_rotate_notice()
	show_title()


# Phones held upright get a "turn your phone" notice instead of a tiny letterboxed game.
func _build_rotate_notice() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_rotate_notice = Control.new()
	_rotate_notice.size = Vector2(1280, 720)
	_rotate_notice.visible = false
	layer.add_child(_rotate_notice)
	var shade := ColorRect.new()
	shade.color = Color(Art.INK, 0.96)
	shade.size = Vector2(1280, 720)
	_rotate_notice.add_child(shade)
	var text := UiKit.label("Please turn your phone sideways", 44, true, Art.ICE)
	text.position = Vector2(0, 300)
	text.size = Vector2(1280, 70)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotate_notice.add_child(text)
	var sub := UiKit.label("GHOSTNET plays in landscape mode", 22, false, Art.CYAN)
	sub.position = Vector2(0, 372)
	sub.size = Vector2(1280, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotate_notice.add_child(sub)


func _process(_delta: float) -> void:
	var window_size := get_window().size
	var portrait := window_size.y > window_size.x * 1.1
	_rotate_notice.visible = portrait
	if portrait and _screen is Run and not get_tree().paused and _overlay == null:
		_open_pause()                       # do not let a dive run while the phone is upright


func show_title() -> void:
	Audio.play_music("music_menu")
	var title := Title.new()
	title.play_pressed.connect(show_slots)
	title.continue_pressed.connect(func(slot: int): _begin(slot, false))
	title.settings_pressed.connect(_open_settings)
	title.story_pressed.connect(show_gallery)
	title.quit_pressed.connect(func(): get_tree().quit())
	_show(title)


func show_slots() -> void:
	Audio.play_music("music_menu")
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
		show_scene("intro", show_workshop)
	else:
		show_workshop()


# A cutscene as a full screen. It counts as seen as soon as it starts.
func show_scene(id: String, then: Callable) -> void:
	Game.mark_scene_seen(id)
	var cutscene := Cutscene.new()
	cutscene.setup(id)
	cutscene.finished.connect(then)
	_show(cutscene)


# Several scenes one after another, then `then`.
func _play_scenes(ids: Array, then: Callable) -> void:
	if ids.is_empty():
		then.call()
	else:
		show_scene(String(ids[0]), func(): _play_scenes(ids.slice(1), then))


func show_gallery() -> void:
	Audio.play_music("music_menu")
	var gallery := StoryGallery.new()
	gallery.scene_chosen.connect(func(id: String): show_scene(id, show_gallery))
	gallery.back_pressed.connect(show_title)
	_show(gallery)


func show_workshop() -> void:
	Audio.play_music("music_menu")
	var workshop := Workshop.new()
	workshop.dive_pressed.connect(start_run)
	workshop.menu_pressed.connect(show_title)
	_show(workshop)


func start_run(skip_story := false) -> void:
	if not skip_story and Game.level("net_return") >= 1 and not Game.scene_seen("net_return"):
		show_scene("net_return", start_run)     # the first net brought home, before the next dive
		return
	Audio.play_music("music_dive")
	var run := Run.new()
	run.process_mode = Node.PROCESS_MODE_PAUSABLE
	run.finished.connect(_on_run_finished)
	run.story_moment.connect(_play_in_dive)
	_show(run)


# A wall's meeting scene inside the dive: pause, play it on top, then carry on at the same speed.
func _play_in_dive(id: String) -> void:
	if _overlay != null:
		return
	Game.mark_scene_seen(id)
	get_tree().paused = true
	Engine.time_scale = 1.0
	Audio.set_loop("boost_loop", false)
	var layer := CanvasLayer.new()
	layer.layer = 50                            # above the dive's darkness and HUD layers
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var cutscene := Cutscene.new()
	cutscene.setup(id)
	cutscene.finished.connect(_resume)
	layer.add_child(cutscene)
	_overlay = layer
	add_child(layer)


# Debug: play any cutscene from wherever we are (over the dive, or as a full screen).
func debug_play_scene(id: String) -> void:
	if _screen is Run:
		_play_in_dive(id)
	else:
		show_scene(id, show_workshop)


func _on_run_finished(result: Dictionary) -> void:
	Engine.time_scale = 1.0
	Game.bank_run(result)
	var scenes := []
	for index in result.get("walls_torn", []):
		var id: String = "ending" if index == Balance.WALLS.size() - 1 else "wall%d_torn" % index
		if not Game.scene_seen(id):
			scenes.append(id)
	_play_scenes(scenes, func(): show_results(result))


func show_results(result: Dictionary) -> void:
	var results := Results.new()
	results.result = result
	results.continue_pressed.connect(show_workshop)
	_show(results)


# ---- Overlays: settings and the Esc menu ----
# Overlays sit on their own CanvasLayer, above the dive's darkness and HUD, so they are always readable.

func _add_overlay(node: Control) -> void:
	_close_overlay()
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(node)
	_overlay = layer
	add_child(layer)


func _open_settings() -> void:
	var panel := SettingsPanel.new()
	panel.closed.connect(_close_overlay)
	_add_overlay(panel)


# Esc: in a dive this pauses; on other screens it is a menu over the screen.
func _open_pause() -> void:
	var in_dive := _screen is Run
	if in_dive:
		get_tree().paused = true
	var menu := PauseMenu.new()
	menu.in_dive = in_dive
	menu.show_main_menu = not (_screen is Title)
	menu.resume_pressed.connect(_resume)
	menu.settings_pressed.connect(func():
		var panel := SettingsPanel.new()
		panel.process_mode = Node.PROCESS_MODE_ALWAYS
		panel.closed.connect(_open_pause)                # back to the Esc menu
		_add_overlay(panel))
	menu.quit_pressed.connect(func():
		_resume()
		Engine.time_scale = 1.0
		show_workshop())
	menu.menu_pressed.connect(func():
		_resume()
		Engine.time_scale = 1.0
		show_title())
	menu.exit_pressed.connect(func(): get_tree().quit())
	_add_overlay(menu)


func _resume() -> void:
	_close_overlay()
	get_tree().paused = false


func _close_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


# Esc opens the menu on every screen except cutscenes (there Esc skips the scene).
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or _overlay != null or _screen is Cutscene:
		return
	if _screen is Run and (_screen as Run).ended:
		return                                    # Pip is already towing Nova up
	_open_pause()
	get_viewport().set_input_as_handled()


# Debug keys, also live in the web build (listed in the README). Only in DEBUG mode.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not Debug.active:
		return                                  # the real game: no debug keys at all
	var key := (event as InputEventKey).keycode
	if key == KEY_F9 or key == KEY_QUOTELEFT:
		Debug.toggle_panel()                    # the developer panel (autoload/debug.gd)
		return
	match key:
		KEY_F1: Game.debug_reset()
		KEY_F2: Game.debug_add_tags()
		KEY_F3: Game.debug_mid_save()
		KEY_F4: Game.debug_unlock_endless()
		KEY_F5: Game.debug_unlock_scenes()
		_: return
	if _screen is Workshop:
		show_workshop()              # rebuild so the new numbers show up


func _show(screen: Node) -> void:
	_close_overlay()
	if _screen:
		_screen.queue_free()
	_screen = screen
	add_child(screen)
