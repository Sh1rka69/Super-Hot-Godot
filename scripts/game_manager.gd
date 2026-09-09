extends Node

## GameManager Autoload for "Very Hot"
## Handles time dilation, score, game states, settings, and level reloading.

signal time_scale_changed(scale: float)
signal enemy_killed()
signal player_damaged(current_hp: int)
signal game_restarted()
signal victory_achieved()

enum GameState { MENU, PLAYING, PAUSED, VICTORY, GAME_OVER }

const MIN_TIME_SCALE: float = 0.035
const NORMAL_TIME_SCALE: float = 1.0
const SPRINT_TIME_SCALE: float = 1.25

var current_state: GameState = GameState.PLAYING
var target_time_scale: float = MIN_TIME_SCALE
var current_time_scale: float = MIN_TIME_SCALE
var activity_timer: float = 0.0

var enemies_killed_count: int = 0
var total_enemies: int = 1
var is_mobile: bool = false
var touch_look_sensitivity: float = 0.0035
var mouse_look_sensitivity: float = 0.002
var sound_volume: float = 1.0
var high_performance_mode: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var os_name: String = OS.get_name()
	is_mobile = os_name == "Android" or os_name == "iOS" or DisplayServer.is_touchscreen_available()
	Engine.time_scale = MIN_TIME_SCALE
	current_time_scale = MIN_TIME_SCALE
	target_time_scale = MIN_TIME_SCALE

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
	
	# Smoothly interpolate time scale
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
	
	# Unpause tree if paused
	get_tree().paused = false
	
	# Release mouse on mobile, capture on PC
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
