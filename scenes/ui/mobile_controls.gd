extends CanvasLayer

## Mobile Touch HUD for "Very Hot"
## Coordinates Virtual Joystick, Touch Camera Look Area, and Action Buttons (Jump, Crouch, Run, Action, Pause)

signal pause_requested()

var player: Node3D = null
var look_touch_index: int = -1
var look_touch_start: Vector2 = Vector2.ZERO
var is_sprint_locked: bool = false

@onready var joystick = $Control/JoystickContainer/VirtualJoystick
@onready var look_area = $Control/TouchLookArea
@onready var btn_jump = $Control/RightButtons/JumpButton
@onready var btn_crouch = $Control/RightButtons/CrouchButton
@onready var btn_run = $Control/RightButtons/RunButton
@onready var btn_action = $Control/RightButtons/ActionButton
@onready var btn_pause = $Control/TopRight/PauseButton

func _ready() -> void:
	_find_player()
	_connect_controls()

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _connect_controls() -> void:
	if joystick:
		joystick.joystick_moved.connect(_on_joystick_moved)
		joystick.joystick_released.connect(_on_joystick_released)
	
	if btn_jump:
		btn_jump.pressed.connect(_on_jump_pressed)
	
	if btn_crouch:
		btn_crouch.pressed.connect(_on_crouch_pressed)
	
	if btn_run:
		btn_run.pressed.connect(_on_run_pressed)
	
	if btn_action:
		btn_action.pressed.connect(_on_action_pressed)
	
	if btn_pause:
		btn_pause.pressed.connect(_on_pause_pressed)
	
	if look_area:
		look_area.gui_input.connect(_on_look_area_input)

func _on_joystick_moved(vec: Vector2) -> void:
	if not player or not is_instance_valid(player):
		_find_player()
	if player and player.has_method("set_mobile_movement"):
		player.set_mobile_movement(vec, is_sprint_locked)

func _on_joystick_released() -> void:
	if player and is_instance_valid(player) and player.has_method("set_mobile_movement"):
		player.set_mobile_movement(Vector2.ZERO, is_sprint_locked)

func _on_jump_pressed() -> void:
	_animate_button_press(btn_jump)
	if not player or not is_instance_valid(player):
		_find_player()
	if player and player.has_method("do_jump"):
		player.do_jump()

func _on_crouch_pressed() -> void:
	_animate_button_press(btn_crouch)
	if not player or not is_instance_valid(player):
		_find_player()
	if player and player.has_method("toggle_crouch"):
		player.toggle_crouch()

func _on_run_pressed() -> void:
	_animate_button_press(btn_run)
	is_sprint_locked = not is_sprint_locked
	if btn_run:
		btn_run.modulate = Color(1.0, 0.4, 0.4, 1.0) if is_sprint_locked else Color(1.0, 1.0, 1.0, 0.85)

func _on_action_pressed() -> void:
	_animate_button_press(btn_action)
	if not player or not is_instance_valid(player):
		_find_player()
	if player and player.has_method("do_primary_action"):
		player.do_primary_action()

func _on_pause_pressed() -> void:
	_animate_button_press(btn_pause)
	pause_requested.emit()
	GameManager.toggle_pause()

func _animate_button_press(btn: Control) -> void:
	if not btn: return
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.88, 0.88), 0.05)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)

func _on_look_area_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if look_touch_index == -1 and event.index != joystick.touch_index:
				look_touch_index = event.index
				look_touch_start = event.position
		else:
			if event.index == look_touch_index:
				look_touch_index = -1
	
	elif event is InputEventScreenDrag:
		if event.index == look_touch_index:
			if not player or not is_instance_valid(player):
				_find_player()
			if player and player.has_method("apply_touch_look"):
				player.apply_touch_look(event.relative)
	
	# Mouse drag fallback for PC testing
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not player or not is_instance_valid(player):
			_find_player()
		if player and player.has_method("apply_touch_look"):
			player.apply_touch_look(event.relative)
