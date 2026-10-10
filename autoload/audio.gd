extends Node
# Sound: one-shot effects from a small pool of players, two looping beds (ambient, booster),
# spoken voice-over clips, and volume buses (Music, SFX, Voice) controlled from the settings screen.
# Autoload name: Audio.

const ONE_SHOTS := ["alarm", "pickup", "net_hit", "o2", "splash", "launch", "wall_break", "cut",
		"wall_hit", "buy", "run_end", "fuel", "click", "whale_song"]
const POOL_SIZE := 10
const MUSIC_TRACKS := ["music_menu", "music_dive"]
const MUSIC_DB := -7.0         # level of the music track that is playing
const SILENT_DB := -60.0
const VOICE_DIR := "res://assets/voice/%s.mp3"
const DUCK_DB := -9.0          # music drops this much while a voice is speaking

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _loops := {}                 # name -> AudioStreamPlayer
var _alarm_timer := 0.0
var _current_music := ""
var _voice: AudioStreamPlayer
var _duck := 0.0               # current music dip in dB, eased toward DUCK_DB or 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
	for sound in ONE_SHOTS:
		_streams[sound] = load("res://assets/audio/%s.wav" % sound)
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_pool.append(player)
	_make_loop("ambient_loop", "Music", -13.0)
	for track in MUSIC_TRACKS:
		_make_loop(track, "Music", SILENT_DB)
	_make_loop("boost_loop", "SFX", -4.0)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	add_child(_voice)
	apply_volumes()
	set_loop("ambient_loop", true)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sound):
		return
	for player in _pool:
		if not player.playing:
			player.stream = _streams[sound]
			player.volume_db = volume_db
			player.pitch_scale = pitch
			player.play()
			return


# ---- Voice-over (clips made by tools/make_voices.py) ----

func has_voice(id: String) -> bool:
	return id != "" and ResourceLoader.exists(VOICE_DIR % id)


# Speak one line. A new line cuts off the previous one. Missing clips are simply silent.
func play_voice(id: String) -> void:
	_voice.stop()
	if has_voice(id):
		_voice.stream = load(VOICE_DIR % id)
		_voice.play()


func stop_voice() -> void:
	_voice.stop()


func voice_length(id: String) -> float:
	if not has_voice(id):
		return 0.0
	return (load(VOICE_DIR % id) as AudioStream).get_length()


func _process(delta: float) -> void:
	var target := DUCK_DB if _voice.playing else 0.0
	_duck = move_toward(_duck, target, delta * 30.0)            # quick dip, smooth return
	var music := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(music, linear_to_db(maxf(float(Game.settings["music"]), 0.0001)) + _duck)


func set_loop(sound: String, on: bool) -> void:
	var player: AudioStreamPlayer = _loops.get(sound)
	if player == null:
		return
	if on and not player.playing:
		player.play()
	elif not on and player.playing:
		player.stop()


# Fade to a music track (menus use music_menu, the dive uses music_dive). Safe to call every screen change.
func play_music(track: String) -> void:
	if track == _current_music:
		return
	_current_music = track
	for name in MUSIC_TRACKS:
		var player: AudioStreamPlayer = _loops[name]
		var wanted: bool = name == track
		if wanted and not player.playing:
			player.volume_db = SILENT_DB
			player.play()
		var tween := create_tween()
		tween.tween_property(player, "volume_db", MUSIC_DB if wanted else SILENT_DB, 1.5)
		if not wanted:
			tween.tween_callback(player.stop)


# Called each frame during a dive with the oxygen fraction: beeps faster when critical.
func low_oxygen_alarm(active: bool, delta: float) -> void:
	_alarm_timer -= delta
	if active and _alarm_timer <= 0.0:
		play("alarm", -8.0)
		_alarm_timer = 0.9


func apply_volumes() -> void:
	var master: float = Game.settings["master"]
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(maxf(master, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(float(Game.settings["music"]), 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(float(Game.settings["sfx"]), 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear_to_db(maxf(float(Game.settings["voice"]), 0.0001)))
	# The ON/OFF switches mute a whole bus, so a slider can stay where the player left it.
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not bool(Game.settings["music_on"]))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not bool(Game.settings["sfx_on"]))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Voice"), not bool(Game.settings["voice_on"]))


func _make_loop(file_name: String, bus_name: String, volume_db: float) -> void:
	var stream: AudioStreamWAV = load("res://assets/audio/%s.wav" % file_name)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	var bytes_per_frame := (2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if stream.stereo else 1)
	stream.loop_end = stream.data.size() / bytes_per_frame
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus_name
	player.volume_db = volume_db
	add_child(player)
	_loops[file_name] = player
