extends Control

## Main Menu for "Very Hot"
## Features interactive live 3D background with instant visual feedback for graphics settings.

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
@onready var check_rays = $UI/SettingsModal/Panel/VBoxContainer/ScrollContainer/VBox/GraphicsBox/CheckRays
@onready var check_bloom = $UI/SettingsModal/Panel/VBoxContainer/ScrollContainer/VBox/GraphicsBox/CheckBloom

@onready var controls_modal = $UI/ControlsModal
@onready var btn_close_controls = $UI/ControlsModal/Panel/VBoxContainer/CloseControlsButton

@onready var menu_cam = $Menu3D/CameraPivot/Camera3D
@onready var cam_pivot = $Menu3D/CameraPivot
@onready var world_env = $Menu3D/WorldEnvironment
@onready var dir_light = $Menu3D/DirectionalLight3D
@onready var sun_rays = $Menu3D/SunRays
@onready var preview_enemy = $Menu3D/PreviewEnemy

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
	
	_init_settings_ui()
	GameManager.apply_graphics_to_current_scene(world_env, dir_light, sun_rays)
	GameManager.graphics_settings_changed.connect(_on_graphics_changed)

func _process(delta: float) -> void:
	if cam_pivot:
		cam_pivot.rotate_y(delta * 0.1)

func _on_graphics_changed() -> void:
	GameManager.apply_graphics_to_current_scene(world_env, dir_light, sun_rays)
	if preview_enemy and preview_enemy.has_method("_update_crystal_materials"):
		preview_enemy._update_crystal_materials()

func _init_settings_ui() -> void:
	if sens_slider:
		sens_slider.value = GameManager.touch_look_sensitivity * 1000.0
		sens_slider.value_changed.connect(_on_sens_changed)
	
	if vol_slider:
		vol_slider.value = GameManager.sound_volume * 100.0
		vol_slider.value_changed.connect(_on_vol_changed)
	
	if check_shadows:
		check_shadows.button_pressed = GameManager.shadows_enabled
		check_shadows.toggled.connect(func(val): GameManager.set_graphics_param("shadows", val))
	
	if check_ssao:
		check_ssao.button_pressed = GameManager.ssao_enabled
		check_ssao.toggled.connect(func(val): GameManager.set_graphics_param("ssao", val))
	
	if check_rays:
		check_rays.button_pressed = GameManager.volumetric_rays_enabled
		check_rays.toggled.connect(func(val): GameManager.set_graphics_param("volumetric_rays", val))
	
	if check_bloom:
		check_bloom.button_pressed = GameManager.bloom_enabled
		check_bloom.toggled.connect(func(val): GameManager.set_graphics_param("bloom", val))

func _on_play_pressed() -> void:
	GameManager.restart_game()

func _on_settings_pressed() -> void:
	_init_settings_ui()
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
