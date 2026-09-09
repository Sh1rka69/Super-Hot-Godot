extends Node

## SoundManager Autoload
## Handles playing synthesized sound effects with pitch modulation matching time scale.

var sound_hit: AudioStreamWAV
var sound_shoot: AudioStreamWAV
var sound_shatter: AudioStreamWAV
var sound_whoosh: AudioStreamWAV
var sound_jump: AudioStreamWAV
var sound_victory: AudioStreamWAV

var audio_pool: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_sounds()
	_create_audio_pool()

func _load_sounds() -> void:
	if ResourceLoader.exists("res://assets/sounds/hit.wav"):
		sound_hit = load("res://assets/sounds/hit.wav")
	if ResourceLoader.exists("res://assets/sounds/shoot.wav"):
		sound_shoot = load("res://assets/sounds/shoot.wav")
	if ResourceLoader.exists("res://assets/sounds/shatter.wav"):
		sound_shatter = load("res://assets/sounds/shatter.wav")
	if ResourceLoader.exists("res://assets/sounds/whoosh.wav"):
		sound_whoosh = load("res://assets/sounds/whoosh.wav")
	if ResourceLoader.exists("res://assets/sounds/jump.wav"):
		sound_jump = load("res://assets/sounds/jump.wav")
	if ResourceLoader.exists("res://assets/sounds/victory.wav"):
		sound_victory = load("res://assets/sounds/victory.wav")

func _create_audio_pool() -> void:
	for i in range(POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		audio_pool.append(player)

func _get_available_player() -> AudioStreamPlayer:
	for p in audio_pool:
		if not p.playing:
			return p
	return audio_pool[0]

func play_hit() -> void:
	if sound_hit:
		var p: AudioStreamPlayer = _get_available_player()
		p.stream = sound_hit
		p.pitch_scale = randf_range(0.9, 1.1)
		p.volume_db = 0.0
		p.play()

func play_shoot() -> void:
	if sound_shoot:
		var p: AudioStreamPlayer = _get_available_player()
		p.stream = sound_shoot
		p.pitch_scale = randf_range(0.95, 1.05)
		p.volume_db = 1.0
		p.play()

func play_shatter() -> void:
	if sound_shatter:
		var p: AudioStreamPlayer = _get_available_player()
		p.stream = sound_shatter
		p.pitch_scale = randf_range(0.9, 1.1)
		p.volume_db = 2.0
		p.play()

func play_whoosh() -> void:
	if sound_whoosh:
		var p: AudioStreamPlayer = _get_available_player()
		p.stream = sound_whoosh
		p.pitch_scale = randf_range(0.95, 1.1)
		p.volume_db = -3.0
		p.play()

func play_jump() -> void:
	if sound_jump:
		var p: AudioStreamPlayer = _get_available_player()
		p.stream = sound_jump
		p.pitch_scale = randf_range(0.95, 1.05)
		p.volume_db = -2.0
		p.play()

func play_victory() -> void:
	if sound_victory:
		var p: AudioStreamPlayer = _get_available_player()
		p.stream = sound_victory
		p.pitch_scale = 1.0
		p.volume_db = 3.0
		p.play()
