extends CanvasLayer

## Pause Menu for "Very Hot"
## Allows in-game real-time graphics and control settings adjustments.

@onready var panel = $Control/Panel
@onready var resume_btn = $Control/Panel/VBoxContainer/ResumeButton
@onready var restart_btn = $Control/Panel/VBoxContainer/RestartButton
@onready var menu_btn = $Control/Panel/VBoxContainer/MenuButton
@onready var sens_slider = $Control/Panel/VBoxContainer/SensContainer/HSlider

@onready var check_shadows = $Control/Panel/VBoxContainer/GraphicsBox/CheckShadows
@onready var check_ssao = $Control/Panel/VBoxContainer/GraphicsBox/CheckSSAO
@onready var check_rays = $Control/Panel/VBoxContainer/GraphicsBox/CheckRays
@onready var check_bloom = $Control/Panel/VBoxContainer/GraphicsBox/CheckBloom

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	
	if resume_btn:
		resume_btn.pressed.connect(_on_resume_pressed)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)
	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)
	
	_init_ui()

func _init_ui() -> void:
	if sens_slider:
		sens_slider.value = GameManager.touch_look_sensitivity * 1000.0
		sens_slider.value_changed.connect(_on_sens_changed)
	
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		toggle_pause()

func toggle_pause() -> void:
	if GameManager.current_state == GameManager.GameState.PAUSED:
		hide_menu()
		GameManager.toggle_pause()
	elif GameManager.current_state == GameManager.GameState.PLAYING:
		show_menu()
		GameManager.toggle_pause()

func show_menu() -> void:
	_init_ui()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_menu() -> void:
	visible = false
	if not GameManager.is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume_pressed() -> void:
	hide_menu()
	GameManager.toggle_pause()

func _on_restart_pressed() -> void:
	hide_menu()
	GameManager.restart_game()

func _on_menu_pressed() -> void:
	hide_menu()
	GameManager.go_to_main_menu()

func _on_sens_changed(val: float) -> void:
	GameManager.touch_look_sensitivity = val / 1000.0
	GameManager.save_settings()
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].touch_sensitivity = GameManager.touch_look_sensitivity
