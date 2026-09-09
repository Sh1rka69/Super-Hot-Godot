extends Node

## GameManager Autoload for "Very Hot"
## Manages game state, time dilation, audio, and persistent graphics settings.

signal time_scale_changed(scale: float)
signal enemy_killed()
signal player_damaged(current_hp: int)
signal game_restarted()
signal victory_achieved()
signal graphics_settings_changed()

enum GameState { MENU, PLAYING, PAUSED, VICTORY, GAME_OVER }

const MIN_TIME_SCALE: float = 0.035
const NORMAL_TIME_SCALE: float = 1.0
const SPRINT_TIME_SCALE: float = 1.25
const SETTINGS_FILE_PATH: String = "user://settings.cfg"

var current_state: GameState = GameState.PLAYING
var target_time_scale: float = MIN_TIME_SCALE
var current_time_scale: float = MIN_TIME_SCALE
var activity_timer: float = 0.0

var enemies_killed_count: int = 0
var total_enemies: int = 1
var is_mobile: bool = false

# Persistent Settings
var touch_look_sensitivity: float = 0.0035
var mouse_look_sensitivity: float = 0.0025
var sound_volume: float = 1.0

# Graphics Settings
var shadows_enabled: bool = true
var ssao_enabled: bool = true
var bloom_enabled: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var os_name: String = OS.get_name()
	is_mobile = os_name == "Android" or os_name == "iOS" or DisplayServer.is_touchscreen_available()
	Engine.time_scale = MIN_TIME_SCALE
	current_time_scale = MIN_TIME_SCALE
	target_time_scale = MIN_TIME_SCALE
	
	load_settings()

func _process(delta: float) -> void:
	if current_state == GameState.PAUSED:
		Engine.time_scale = 0.0
		return
	
	if current_state == GameState.MENU:
		Engine.time_scale = 1.0
		return
	
	if activity_timer > 0.0:
		activity_timer -= delta / max(0.001, current_time_scale)
		if activity_timer <= 0.0:
			target_time_scale = MIN_TIME_SCALE
	
	var real_delta: float = delta / max(0.001, current_time_scale) if current_time_scale > 0.01 else 0.016
	current_time_scale = lerpf(current_time_scale, target_time_scale, clampf(real_delta * 14.0, 0.0, 1.0))
	Engine.time_scale = clampf(current_time_scale, 0.01, SPRINT_TIME_SCALE)
	time_scale_changed.emit(current_time_scale)

func request_time_scale(activity_intensity: float, duration: float = 0.06) -> void:
	if current_state != GameState.PLAYING:
		return
	var clamped_intensity: float = clampf(activity_intensity, 0.0, 1.0)
	var new_target: float = lerpf(MIN_TIME_SCALE, NORMAL_TIME_SCALE, clamped_intensity)
	if clamped_intensity >= 0.95:
		new_target = SPRINT_TIME_SCALE
	target_time_scale = maxf(target_time_scale, new_target)
	activity_timer = maxf(activity_timer, duration)

func on_enemy_defeated() -> void:
	enemies_killed_count += 1
	enemy_killed.emit()
	if enemies_killed_count >= total_enemies:
		trigger_victory()

func trigger_victory() -> void:
	current_state = GameState.VICTORY
	victory_achieved.emit()
	target_time_scale = 0.2
	activity_timer = 3.0

func trigger_game_over() -> void:
	current_state = GameState.GAME_OVER
	target_time_scale = 0.15
	activity_timer = 3.0

func restart_game() -> void:
	current_state = GameState.PLAYING
	enemies_killed_count = 0
	target_time_scale = MIN_TIME_SCALE
	current_time_scale = MIN_TIME_SCALE
	Engine.time_scale = MIN_TIME_SCALE
	game_restarted.emit()
	get_tree().paused = false
	
	if is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func go_to_main_menu() -> void:
	current_state = GameState.MENU
	Engine.time_scale = 1.0
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func toggle_pause() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		Engine.time_scale = current_time_scale
		if not is_mobile:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		Engine.time_scale = 0.0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# ==========================================
# Persistent Settings Management (Auto-Save)
# ==========================================

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("graphics", "shadows", shadows_enabled)
	config.set_value("graphics", "ssao", ssao_enabled)
	config.set_value("graphics", "bloom", bloom_enabled)
	
	config.set_value("controls", "touch_sensitivity", touch_look_sensitivity)
	config.set_value("audio", "volume", sound_volume)
	
	config.save(SETTINGS_FILE_PATH)
	graphics_settings_changed.emit()
	apply_graphics_to_current_scene()

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE_PATH)
	if err == OK:
		shadows_enabled = config.get_value("graphics", "shadows", true)
		ssao_enabled = config.get_value("graphics", "ssao", true)
		bloom_enabled = config.get_value("graphics", "bloom", true)
		
		touch_look_sensitivity = config.get_value("controls", "touch_sensitivity", 0.0035)
		sound_volume = config.get_value("audio", "volume", 1.0)
	
	AudioServer.set_bus_volume_db(0, linear_to_db(sound_volume))

func set_graphics_param(param_name: String, value: bool) -> void:
	match param_name:
		"shadows": shadows_enabled = value
		"ssao": ssao_enabled = value
		"bloom": bloom_enabled = value
	save_settings()

func apply_graphics_to_current_scene(world_env: WorldEnvironment = null, dir_light: DirectionalLight3D = null) -> void:
	# 1. World Environment
	if world_env == null:
		var env_nodes = get_tree().get_nodes_in_group("world_environment")
		if env_nodes.size() > 0:
			world_env = env_nodes[0] as WorldEnvironment
	
	if world_env and world_env.environment:
		var env: Environment = world_env.environment
		
		# SSAO (Screen Space Ambient Occlusion / Угловые тени)
		env.ssao_enabled = ssao_enabled
		if ssao_enabled:
			env.ssao_radius = 1.2
			env.ssao_intensity = 3.0
			env.ssao_power = 1.8
			env.ssao_detail = 0.6
			env.ambient_light_energy = 0.8
		else:
			env.ambient_light_energy = 1.1
		
		# Bloom & Glow (мягкий и приятный)
		env.glow_enabled = bloom_enabled
		if bloom_enabled:
			env.glow_normalized = false
			env.glow_intensity = 0.35
			env.glow_strength = 0.85
			env.glow_bloom = 0.12
			env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
			env.glow_hdr_threshold = 1.0
	
	# 2. Directional Light (Sun)
	if dir_light == null:
		var light_nodes = get_tree().get_nodes_in_group("directional_light")
		if light_nodes.size() > 0:
			dir_light = light_nodes[0] as DirectionalLight3D
	
	if dir_light:
		dir_light.shadow_enabled = shadows_enabled
