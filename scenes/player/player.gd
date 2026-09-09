extends CharacterBody3D

## Player Controller for "Very Hot"
## Supports Mobile Touch Joystick + Right-screen Camera Drag + PC Keyboard/Mouse Controls
## Coordinates Time Dilation with movement and camera activity.

@export var walk_speed: float = 4.2
@export var run_speed: float = 7.8
@export var crouch_speed: float = 2.2
@export var jump_velocity: float = 5.6
@export var gravity: float = 18.0

@export var max_hp: int = 100
var current_hp: int = 100
var is_dead: bool = false

# Movement & state flags
var is_running: bool = false
var is_crouching: bool = false
var normal_camera_y: float = 1.65
var crouch_camera_y: float = 0.85
var normal_capsule_height: float = 1.8
var crouch_capsule_height: float = 1.0

# Mobile input vector from joystick
var mobile_move_vector: Vector2 = Vector2.ZERO
var mobile_look_delta: Vector2 = Vector2.ZERO

# Camera rotation
var camera_pitch: float = 0.0
var mouse_sensitivity: float = 0.0025
var touch_sensitivity: float = 0.004

# Weapon & interaction
var held_weapon: Node3D = null
var punch_cooldown: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var hand: Node3D = $Head/Hand
@onready var fist_mesh: Node3D = $Head/Hand/FistMesh
@onready var aim_ray: RayCast3D = $Head/AimRay
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var punch_area: Area3D = $Head/PunchArea

const PISTOL_SCENE: PackedScene = preload("res://scenes/weapons/pistol.tscn")

func _ready() -> void:
	current_hp = max_hp
	if fist_mesh:
		fist_mesh.visible = false
	
	# Connect punch area
	if punch_area:
		punch_area.body_entered.connect(_on_punch_area_body_entered)
		punch_area.monitoring = false
	
	# On desktop, capture mouse on start/click
	if not GameManager.is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	
	# PC Mouse Look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var look_delta = event.relative * mouse_sensitivity
		_apply_look(look_delta)
		GameManager.request_time_scale(clampf(look_delta.length() * 15.0, 0.1, 0.8), 0.08)
	
	# PC Click to capture mouse or attack
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not GameManager.is_mobile:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_LEFT:
			do_primary_action()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			throw_held_weapon()

func _apply_look(delta_vec: Vector2) -> void:
	# Horizontal look (Yaw on player body)
	rotate_y(-delta_vec.x)
	# Vertical look (Pitch on camera head)
	camera_pitch = clampf(camera_pitch - delta_vec.y, -deg_to_rad(85), deg_to_rad(85))
	head.rotation.x = camera_pitch

func apply_touch_look(relative_delta: Vector2) -> void:
	if is_dead:
		return
	var look_delta = relative_delta * touch_sensitivity
	_apply_look(look_delta)
	# Activity pushes time scale
	GameManager.request_time_scale(clampf(look_delta.length() * 20.0, 0.15, 0.85), 0.08)

func set_mobile_movement(vec: Vector2, run_flag: bool = false) -> void:
	mobile_move_vector = vec
	if run_flag or vec.length() >= 0.75:
		is_running = true
	else:
		is_running = false

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if punch_cooldown > 0.0:
		punch_cooldown -= delta
	
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	
	# Keyboard / Desktop input
	var kb_input: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("move_forward") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		kb_input.y -= 1.0
	if Input.is_action_pressed("move_backward") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		kb_input.y += 1.0
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		kb_input.x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		kb_input.x += 1.0
	
	if Input.is_key_pressed(KEY_SHIFT):
		is_running = true
	elif mobile_move_vector.length() < 0.75 and not Input.is_key_pressed(KEY_SHIFT):
		is_running = false
	
	if Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_CTRL):
		is_crouching = true
	elif not GameManager.is_mobile and not Input.is_key_pressed(KEY_C) and not Input.is_key_pressed(KEY_CTRL):
		is_crouching = false
	
	if (Input.is_key_pressed(KEY_SPACE) or Input.is_action_just_pressed("jump")) and is_on_floor():
		do_jump()
	
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_F):
		do_primary_action()
	
	# Combine inputs
	var move_vec: Vector2 = mobile_move_vector if mobile_move_vector.length() > 0.01 else kb_input.normalized()
	var input_intensity: float = move_vec.length()
	
	# Determine current speed
	var current_speed: float = walk_speed
	if is_crouching:
		current_speed = crouch_speed
	elif is_running:
		current_speed = run_speed
	
	# Calculate 3D movement direction relative to camera facing
	var move_dir: Vector3 = (transform.basis * Vector3(move_vec.x, 0, move_vec.y)).normalized()
	
	if move_dir.length() > 0.1:
		velocity.x = move_dir.x * current_speed * input_intensity
		velocity.z = move_dir.z * current_speed * input_intensity
		# Notify time dilation
		var activity_val = 1.0 if is_running else 0.75
		GameManager.request_time_scale(activity_val * input_intensity, 0.08)
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 8.0 * delta)
	
	# Smoothly animate crouch height
	var target_cam_y = crouch_camera_y if is_crouching else normal_camera_y
	head.position.y = lerpf(head.position.y, target_cam_y, clampf(delta * 14.0, 0.0, 1.0))
	
	if collision_shape.shape is CapsuleShape3D:
		var target_h = crouch_capsule_height if is_crouching else normal_capsule_height
		collision_shape.shape.height = lerpf(collision_shape.shape.height, target_h, clampf(delta * 14.0, 0.0, 1.0))
		collision_shape.position.y = collision_shape.shape.height * 0.5
	
	move_and_slide()

func do_jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity
		SoundManager.play_jump()
		GameManager.request_time_scale(1.0, 0.25)

func toggle_crouch() -> void:
	is_crouching = not is_crouching
	GameManager.request_time_scale(0.5, 0.1)

func set_crouching(crouch_val: bool) -> void:
	is_crouching = crouch_val
	GameManager.request_time_scale(0.5, 0.1)

func do_primary_action() -> void:
	if is_dead:
		return
	
	GameManager.request_time_scale(1.0, 0.2)
	
	# 1. If near a weapon to pick up
	if try_interact_pickup():
		return
	
	# 2. If holding a weapon, fire it
	if held_weapon and is_instance_valid(held_weapon):
		var target_point: Vector3
		if aim_ray.is_colliding():
			target_point = aim_ray.get_collision_point()
		else:
			target_point = camera.global_position - camera.global_transform.basis.z * 50.0
		
		var shoot_dir = (target_point - hand.global_position).normalized()
		if held_weapon.has_method("shoot"):
			var shot = held_weapon.shoot(shoot_dir, true)
			if not shot or held_weapon.current_ammo <= 0:
				# Out of ammo, throw empty gun!
				throw_held_weapon()
		return
	
	# 3. Otherwise, deliver a melee punch!
	do_punch()

func do_punch() -> void:
	if punch_cooldown > 0.0:
		return
	
	punch_cooldown = 0.35
	SoundManager.play_whoosh()
	
	# Animate fist
	if fist_mesh:
		fist_mesh.visible = true
		fist_mesh.position = Vector3(0.2, -0.2, -0.3)
		var tween = create_tween()
		tween.tween_property(fist_mesh, "position", Vector3(0.1, -0.1, -0.8), 0.08)
		tween.tween_property(fist_mesh, "position", Vector3(0.2, -0.2, -0.3), 0.12)
		tween.tween_callback(func(): fist_mesh.visible = false)
	
	# Check raycast and punch area
	var hit_enemy = false
	if aim_ray.is_colliding():
		var col = aim_ray.get_collider()
		if col and col.is_in_group("enemy") and col.has_method("take_hit"):
			col.take_hit(aim_ray.get_collision_point(), -camera.global_transform.basis.z)
			hit_enemy = true
			SoundManager.play_hit()
	
	if not hit_enemy:
		# Check nearby punch area
		if punch_area:
			punch_area.monitoring = true
			get_tree().create_timer(0.12).timeout.connect(func(): punch_area.monitoring = false)

func _on_punch_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy") and body.has_method("take_hit"):
		body.take_hit(body.global_position, -camera.global_transform.basis.z)
		SoundManager.play_hit()

func try_interact_pickup() -> bool:
	if held_weapon != null:
		return false
	
	if aim_ray.is_colliding():
		var col = aim_ray.get_collider()
		if col and col.is_in_group("weapon") and col.has_method("equip_to_hand"):
			equip_weapon(col)
			return true
	return false

func try_pickup_weapon(weapon_node: Node3D) -> void:
	if held_weapon == null and weapon_node.has_method("equip_to_hand"):
		equip_weapon(weapon_node)

func equip_weapon(weapon_node: Node3D) -> void:
	held_weapon = weapon_node
	weapon_node.equip_to_hand(hand)
	SoundManager.play_hit()

func throw_held_weapon() -> void:
	if held_weapon and is_instance_valid(held_weapon):
		var throw_dir = -camera.global_transform.basis.z
		var throw_impulse = throw_dir * 18.0 + Vector3.UP * 1.5
		held_weapon.drop_or_throw(hand.global_transform, throw_impulse)
		held_weapon = null
		SoundManager.play_whoosh()
		GameManager.request_time_scale(1.0, 0.2)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	
	current_hp -= amount
	SoundManager.play_hit()
	GameManager.player_damaged.emit(current_hp)
	
	if current_hp <= 0:
		is_dead = true
		GameManager.trigger_game_over()
