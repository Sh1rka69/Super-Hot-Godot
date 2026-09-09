extends Control

## Virtual Joystick for Mobile Touch Controls
## Supports smooth circular dragging, multi-touch filtering, and walk/run thresholds.

signal joystick_moved(output_vec: Vector2)
signal joystick_released()

@export var max_distance: float = 80.0
@export var deadzone: float = 0.12

var touch_index: int = -1
var is_active: bool = false
var output: Vector2 = Vector2.ZERO

@onready var base: TextureRect = $Base
@onready var stick: TextureRect = $Base/Stick

func _ready() -> void:
	_center_stick()

func _center_stick() -> void:
	if stick and base:
		stick.position = (base.size - stick.size) * 0.5

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if touch_index == -1:
				touch_index = event.index
				is_active = true
				_update_stick_pos(event.position)
		else:
			if event.index == touch_index:
				_reset_stick()
	
	elif event is InputEventScreenDrag:
		if event.index == touch_index:
			_update_stick_pos(event.position)
	
	# Mouse fallback for editor/desktop testing
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_active = true
				_update_stick_pos(event.position)
			else:
				_reset_stick()
	
	elif event is InputEventMouseMotion and is_active:
		_update_stick_pos(event.position)

func _update_stick_pos(touch_pos: Vector2) -> void:
	var center: Vector2 = size * 0.5
	var offset: Vector2 = touch_pos - center
	var dist: float = offset.length()
	
	if dist > max_distance:
		offset = offset.normalized() * max_distance
	
	stick.position = (base.size - stick.size) * 0.5 + offset
	
	var norm_dist: float = dist / max_distance
	if norm_dist < deadzone:
		output = Vector2.ZERO
	else:
		output = offset / max_distance
	
	joystick_moved.emit(output)

func _reset_stick() -> void:
	touch_index = -1
	is_active = false
	output = Vector2.ZERO
	_center_stick()
	joystick_released.emit()
