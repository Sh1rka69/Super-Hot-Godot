extends CanvasLayer

## Pause Menu for "Very Hot"

@onready var panel = $Control/Panel
@onready var resume_btn = $Control/Panel/VBoxContainer/ResumeButton
@onready var restart_btn = $Control/Panel/VBoxContainer/RestartButton
@onready var sens_slider = $Control/Panel/VBoxContainer/SensContainer/HSlider

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if resume_btn:
		resume_btn.pressed.connect(_on_resume_pressed)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)
	if sens_slider:
		sens_slider.value = GameManager.touch_look_sensitivity * 1000.0
		sens_slider.value_changed.connect(_on_sens_changed)

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
	visible = true
	if not GameManager.is_mobile:
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

func _on_sens_changed(val: float) -> void:
	GameManager.touch_look_sensitivity = val / 1000.0
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].touch_sensitivity = GameManager.touch_look_sensitivity
