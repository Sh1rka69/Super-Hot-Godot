extends Control

## Main Menu for "Very Hot"

@onready var btn_play = $CenterContainer/VBoxContainer/PlayButton
@onready var btn_settings = $CenterContainer/VBoxContainer/SettingsButton
@onready var btn_controls = $CenterContainer/VBoxContainer/ControlsButton
@onready var btn_quit = $CenterContainer/VBoxContainer/QuitButton

@onready var settings_modal = $SettingsModal
@onready var btn_close_settings = $SettingsModal/Panel/VBoxContainer/CloseSettingsButton
@onready var sens_slider = $SettingsModal/Panel/VBoxContainer/SensContainer/HSlider
@onready var vol_slider = $SettingsModal/Panel/VBoxContainer/VolContainer/HSlider

@onready var controls_modal = $ControlsModal
@onready var btn_close_controls = $ControlsModal/Panel/VBoxContainer/CloseControlsButton

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
		sens_slider.value = GameManager.touch_look_sensitivity * 1000.0
		sens_slider.value_changed.connect(_on_sens_changed)
	
	if vol_slider:
		vol_slider.value = GameManager.sound_volume * 100.0
		vol_slider.value_changed.connect(_on_vol_changed)

func _on_play_pressed() -> void:
	GameManager.restart_game()

func _on_settings_pressed() -> void:
	settings_modal.visible = true

func _on_controls_pressed() -> void:
	controls_modal.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_sens_changed(val: float) -> void:
	GameManager.touch_look_sensitivity = val / 1000.0

func _on_vol_changed(val: float) -> void:
	GameManager.sound_volume = val / 100.0
	AudioServer.set_bus_volume_db(0, linear_to_db(GameManager.sound_volume))
