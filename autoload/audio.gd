extends Node
# Sound: one-shot effects from a small pool of players, two looping beds (ambient, booster),
# and volume buses (Music, SFX) controlled from the settings screen.
# Autoload name: Audio.

const ONE_SHOTS := ["alarm", "pickup", "net_hit", "o2", "splash", "launch", "wall_break", "cut",
		"wall_hit", "buy", "run_end", "fuel", "click", "whale_song"]
const POOL_SIZE := 10

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _loops := {}                 # name -> AudioStreamPlayer
var _alarm_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["Music", "SFX"]:
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
	_make_loop("ambient_loop", "Music", -6.0)
	_make_loop("boost_loop", "SFX", -4.0)
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


func set_loop(sound: String, on: bool) -> void:
	var player: AudioStreamPlayer = _loops.get(sound)
	if player == null:
		return
	if on and not player.playing:
		player.play()
	elif not on and player.playing:
		player.stop()


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
