extends Control

## Main Menu for "Very Hot"
## Interactive 3D background with instant settings feedback.

@onready var btn_play = $UI/CenterContainer/VBoxContainer/PlayButton
@onready var btn_settings = $UI/CenterContainer/VBoxContainer/SettingsButton
@onready var btn_controls = $UI/CenterContainer/VBoxContainer/ControlsButton
@onready var btn_quit = $UI/CenterContainer/VBoxContainer/QuitButton

@onready var settings_modal = $UI/SettingsModal
@onready var btn_close_settings = $UI/SettingsModal/Panel/VBoxContainer/CloseSettingsButton
@onready var sens_slider = $UI/SettingsModal/Panel/VBoxContainer/ScrollContainer/VBox/SensContainer/HSlider
@onready var vol_slider = $UI/SettingsModal/Panel/VBoxContainer/ScrollContainer/VBox/VolContainer/HSlider

@onready var check_shadows = $UI/SettingsModal/Panel/VBoxContainer/ScrollContainer/VBox/GraphicsBox/CheckShadows
@onready var check_ssao = $UI/SettingsModal/Panel/VBoxContainer/ScrollContainer/VBox/GraphicsBox/CheckSSAO
@onready var check_bloom = $UI/SettingsModal/Panel/VBoxContainer/ScrollContainer/VBox/GraphicsBox/CheckBloom

@onready var controls_modal = $UI/ControlsModal
@onready var btn_close_controls = $UI/ControlsModal/Panel/VBoxContainer/CloseControlsButton

@onready var cam_pivot = $Menu3D/CameraPivot
@onready var world_env = $Menu3D/WorldEnvironment
@onready var dir_light = $Menu3D/DirectionalLight3D
@onready var enemy_preview_mesh = $Menu3D/EnemyPreviewMesh

func _ready() -> void:
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.current_state = GameManager.GameState.MENU
	
	if settings_modal:
		settings_modal.visible = false
	if controls_modal:
		controls_modal.visible = false
	
	btn_play.pressed.connect(_on_play_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_controls.pressed.connect(_on_controls_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	
	btn_close_settings.pressed.connect(func(): settings_modal.visible = false)
	btn_close_controls.pressed.connect(func(): controls_modal.visible = false)
	
	if sens_slider:
		sens_slider.value_changed.connect(_on_sens_changed)
	if vol_slider:
		vol_slider.value_changed.connect(_on_vol_changed)
	
	if check_shadows:
		check_shadows.toggled.connect(func(val): GameManager.set_graphics_param("shadows", val))
	if check_ssao:
		check_ssao.toggled.connect(func(val): GameManager.set_graphics_param("ssao", val))
	if check_bloom:
		check_bloom.toggled.connect(func(val): GameManager.set_graphics_param("bloom", val))
	
	_sync_ui_values()
	GameManager.apply_graphics_to_current_scene(world_env, dir_light)
	GameManager.graphics_settings_changed.connect(_on_graphics_changed)

func _process(delta: float) -> void:
	if cam_pivot:
		cam_pivot.rotate_y(delta * 0.1)

func _on_graphics_changed() -> void:
	GameManager.apply_graphics_to_current_scene(world_env, dir_light)
	if enemy_preview_mesh and enemy_preview_mesh.mesh and enemy_preview_mesh.mesh.material:
		var mat = enemy_preview_mesh.mesh.material as StandardMaterial3D
		if mat:
			mat.emission_enabled = GameManager.bloom_enabled
			mat.emission_energy_multiplier = 0.5 if GameManager.bloom_enabled else 0.0

func _sync_ui_values() -> void:
	if sens_slider:
		sens_slider.set_value_no_signal(GameManager.touch_look_sensitivity * 1000.0)
	if vol_slider:
		vol_slider.set_value_no_signal(GameManager.sound_volume * 100.0)
	if check_shadows:
		check_shadows.set_pressed_no_signal(GameManager.shadows_enabled)
	if check_ssao:
		check_ssao.set_pressed_no_signal(GameManager.ssao_enabled)
	if check_bloom:
		check_bloom.set_pressed_no_signal(GameManager.bloom_enabled)

func _on_play_pressed() -> void:
	GameManager.restart_game()

func _on_settings_pressed() -> void:
	_sync_ui_values()
	settings_modal.visible = true

func _on_controls_pressed() -> void:
	controls_modal.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_sens_changed(val: float) -> void:
	GameManager.touch_look_sensitivity = val / 1000.0
	GameManager.save_settings()

func _on_vol_changed(val: float) -> void:
	GameManager.sound_volume = val / 100.0
	AudioServer.set_bus_volume_db(0, linear_to_db(GameManager.sound_volume))
	GameManager.save_settings()
