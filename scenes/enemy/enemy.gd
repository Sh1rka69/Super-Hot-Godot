extends CharacterBody3D

## Enemy Controller for "Very Hot"
## Features fair AI pacing, telegraph delays, and optimized animation switching.

enum EnemyState { IDLE, CHASE, ATTACK_MELEE, ATTACK_RANGED, PICKUP, HIT, DEAD }

@export var max_health: int = 100
@export var chase_speed: float = 3.2
@export var melee_range: float = 1.75
@export var shoot_range: float = 9.0
@export var detection_range: float = 14.0
@export var has_gun: bool = true
@export var spawn_grace_period: float = 2.5 # Player has time to assess and move first

var current_health: int = 100
var current_state: EnemyState = EnemyState.IDLE
var target_player: Node3D = null
var is_dead: bool = false
var state_timer: float = 0.0
var grace_timer: float = 0.0
var aim_windup_timer: float = 0.0
var is_aiming: bool = false

# Model preloads
const MODEL_STANDING_SCENE = preload("res://assets/models/enemy/Standing.fbx")
const MODEL_RUNNING_SCENE = preload("res://assets/models/enemy/Running.fbx")
const MODEL_SHOOTING_SCENE = preload("res://assets/models/enemy/Shooting.fbx")
const MODEL_HOOK_SCENE = preload("res://assets/models/enemy/Right Hook.fbx")
const MODEL_PICKUP_SCENE = preload("res://assets/models/enemy/Pick Up Item.fbx")
const MODEL_HIT_SCENE = preload("res://assets/models/enemy/Light Hit To Head.fbx")
const SHATTER_SCENE = preload("res://scenes/enemy/shatter_debris.tscn")
const PISTOL_SCENE = preload("res://scenes/weapons/pistol.tscn")

var model_nodes: Dictionary = {}
var active_anim_player: AnimationPlayer = null

@onready var models_container: Node3D = $ModelsContainer
@onready var gun_slot: Marker3D = $GunSlot
@onready var los_raycast: RayCast3D = $LOSRayCast
@onready var aim_telegraph: MeshInstance3D = $AimTelegraph

var equipped_pistol: Node3D = null
var crystal_material: StandardMaterial3D

func _ready() -> void:
	current_health = max_health
	grace_timer = spawn_grace_period
	
	if aim_telegraph:
		aim_telegraph.visible = false
	
	_create_crystal_material()
	_instantiate_all_models()
	_find_player()
	
	if has_gun:
		_equip_initial_gun()
	
	set_state(EnemyState.IDLE)

func _create_crystal_material() -> void:
	crystal_material = StandardMaterial3D.new()
	crystal_material.albedo_color = Color(0.95, 0.1, 0.04, 1.0)
	crystal_material.roughness = 0.2
	crystal_material.metallic = 0.15
	crystal_material.emission_enabled = true
	crystal_material.emission = Color(0.8, 0.05, 0.0)
	crystal_material.emission_energy_multiplier = 0.4

func _instantiate_all_models() -> void:
	var model_defs = {
		EnemyState.IDLE: MODEL_STANDING_SCENE,
		EnemyState.CHASE: MODEL_RUNNING_SCENE,
		EnemyState.ATTACK_RANGED: MODEL_SHOOTING_SCENE,
		EnemyState.ATTACK_MELEE: MODEL_HOOK_SCENE,
		EnemyState.PICKUP: MODEL_PICKUP_SCENE,
		EnemyState.HIT: MODEL_HIT_SCENE,
	}
	
	var loaded_count = 0
	for state_key in model_defs:
		var scene: PackedScene = model_defs[state_key]
		if scene:
			var inst = scene.instantiate()
			if inst:
				models_container.add_child(inst)
				_apply_material_recursively(inst, crystal_material)
				inst.visible = false
				model_nodes[state_key] = inst
				_configure_animation(inst, state_key)
				loaded_count += 1
	
	if loaded_count == 0:
		_create_fallback_humanoid()

func _create_fallback_humanoid() -> void:
	var fallback_root = Node3D.new()
	fallback_root.name = "FallbackHumanoid"
	
	var head_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	sphere.material = crystal_material
	head_mesh.mesh = sphere
	head_mesh.position = Vector3(0, 1.55, 0)
	fallback_root.add_child(head_mesh)
	
	var torso_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.42, 0.65, 0.22)
	box.material = crystal_material
	torso_mesh.mesh = box
	torso_mesh.position = Vector3(0, 1.05, 0)
	fallback_root.add_child(torso_mesh)
	
	var leg_l = MeshInstance3D.new()
	var leg_mesh = BoxMesh.new()
	leg_mesh.size = Vector3(0.14, 0.72, 0.14)
	leg_mesh.material = crystal_material
	leg_l.mesh = leg_mesh
	leg_l.position = Vector3(-0.12, 0.36, 0)
	fallback_root.add_child(leg_l)
	
	var leg_r = MeshInstance3D.new()
	leg_r.mesh = leg_mesh
	leg_r.position = Vector3(0.12, 0.36, 0)
	fallback_root.add_child(leg_r)
	
	models_container.add_child(fallback_root)
	for state_key in [EnemyState.IDLE, EnemyState.CHASE, EnemyState.ATTACK_RANGED, EnemyState.ATTACK_MELEE, EnemyState.PICKUP, EnemyState.HIT]:
		model_nodes[state_key] = fallback_root

func _apply_material_recursively(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		var mesh_inst: MeshInstance3D = node as MeshInstance3D
		mesh_inst.material_override = mat
	for child in node.get_children():
		_apply_material_recursively(child, mat)

func _configure_animation(model_root: Node, state_key: EnemyState) -> void:
	var anim_player: AnimationPlayer = _find_anim_player(model_root)
	if anim_player:
		var anim_list = anim_player.get_animation_list()
		if anim_list.size() > 0:
			var anim_name = anim_list[0]
			var anim: Animation = anim_player.get_animation(anim_name)
			if anim:
				if state_key == EnemyState.IDLE or state_key == EnemyState.CHASE:
					anim.loop_mode = Animation.LOOP_LINEAR
				else:
					anim.loop_mode = Animation.LOOP_NONE

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found = _find_anim_player(child)
		if found:
			return found
	return null

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0]

func _equip_initial_gun() -> void:
	var pistol = PISTOL_SCENE.instantiate()
	get_tree().current_scene.add_child.call_deferred(pistol)
	pistol.equip_to_hand.call_deferred(gun_slot)
	equipped_pistol = pistol

func set_state(new_state: EnemyState) -> void:
	if is_dead and new_state != EnemyState.DEAD and new_state != EnemyState.HIT:
		return
	
	current_state = new_state
	state_timer = 0.0
	is_aiming = false
	if aim_telegraph:
		aim_telegraph.visible = false
	
	for state_key in model_nodes:
		var model = model_nodes[state_key]
		if state_key == new_state:
			model.visible = true
			var anim_p: AnimationPlayer = _find_anim_player(model)
			if anim_p:
				var anim_list = anim_p.get_animation_list()
				if anim_list.size() > 0:
					anim_p.play(anim_list[0])
					active_anim_player = anim_p
		else:
			model.visible = false
			var anim_p: AnimationPlayer = _find_anim_player(model)
			if anim_p:
				anim_p.stop()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if not target_player or not is_instance_valid(target_player):
		_find_player()
		if not target_player:
			return
	
	if grace_timer > 0.0:
		grace_timer -= delta
	
	state_timer += delta
	
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	
	var to_player: Vector3 = target_player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	
	# Look towards player
	if dist > 0.1 and current_state != EnemyState.HIT and current_state != EnemyState.DEAD:
		var target_rot_y = atan2(to_player.x, to_player.z)
		rotation.y = lerp_angle(rotation.y, target_rot_y, clampf(delta * 6.0, 0.0, 1.0))
	
	match current_state:
		EnemyState.IDLE:
			velocity.x = 0.0
			velocity.z = 0.0
			# Only transition after grace period has expired
			if grace_timer <= 0.0 and dist < detection_range:
				if equipped_pistol and dist <= shoot_range:
					set_state(EnemyState.ATTACK_RANGED)
				else:
					set_state(EnemyState.CHASE)
		
		EnemyState.CHASE:
			if dist <= melee_range:
				set_state(EnemyState.ATTACK_MELEE)
			elif equipped_pistol and dist <= shoot_range and randf() < 0.015:
				set_state(EnemyState.ATTACK_RANGED)
			else:
				var dir: Vector3 = to_player.normalized()
				velocity.x = dir.x * chase_speed
				velocity.z = dir.z * chase_speed
		
		EnemyState.ATTACK_MELEE:
			velocity.x = 0.0
			velocity.z = 0.0
			# Punch windup strike at 0.4s
			if state_timer >= 0.4 and state_timer - delta < 0.4:
				_perform_melee_punch()
			if state_timer >= 0.9:
				if dist <= melee_range:
					set_state(EnemyState.ATTACK_MELEE)
				else:
					set_state(EnemyState.CHASE)
		
		EnemyState.ATTACK_RANGED:
			velocity.x = 0.0
			velocity.z = 0.0
			# Aim telegraph laser active for first 0.6s
			if state_timer < 0.7:
				if aim_telegraph:
					aim_telegraph.visible = true
			else:
				if aim_telegraph:
					aim_telegraph.visible = false
			
			# Fire gun at 0.75s (giving player ample time to dodge)
			if state_timer >= 0.75 and state_timer - delta < 0.75:
				_perform_ranged_shot()
			
			if state_timer >= 1.4:
				if dist > melee_range:
					set_state(EnemyState.CHASE)
				else:
					set_state(EnemyState.ATTACK_MELEE)
		
		EnemyState.PICKUP:
			velocity.x = 0.0
			velocity.z = 0.0
			if state_timer >= 1.0:
				set_state(EnemyState.CHASE)
		
		EnemyState.HIT, EnemyState.DEAD:
			velocity.x = 0.0
			velocity.z = 0.0
	
	move_and_slide()

func _perform_melee_punch() -> void:
	SoundManager.play_whoosh()
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= melee_range + 0.6:
			SoundManager.play_hit()
			if target_player.has_method("take_damage"):
				target_player.take_damage(25)

func _perform_ranged_shot() -> void:
	if equipped_pistol and is_instance_valid(equipped_pistol):
		if target_player and is_instance_valid(target_player):
			var shoot_target = target_player.global_position + Vector3(0, 1.1, 0)
			var shoot_dir = (shoot_target - gun_slot.global_position).normalized()
			if equipped_pistol.has_method("shoot"):
				var shot = equipped_pistol.shoot(shoot_dir, false)
				if not shot or equipped_pistol.current_ammo <= 0:
					_drop_weapon()

func _drop_weapon() -> void:
	if equipped_pistol and is_instance_valid(equipped_pistol):
		var drop_impulse = (-global_transform.basis.z + Vector3.UP * 0.5) * 2.0
		equipped_pistol.drop_or_throw(gun_slot.global_transform, drop_impulse)
		equipped_pistol = null

func take_hit(hit_position: Vector3, hit_direction: Vector3) -> void:
	if is_dead:
		return
	
	current_health -= 100
	if current_health <= 0:
		die(hit_position, hit_direction)
	else:
		set_state(EnemyState.HIT)

func die(hit_pos: Vector3, hit_dir: Vector3) -> void:
	if is_dead:
		return
	
	is_dead = true
	current_state = EnemyState.DEAD
	
	if aim_telegraph:
		aim_telegraph.visible = false
	
	_drop_weapon()
	
	SoundManager.play_hit()
	SoundManager.play_shatter()
	
	var debris = SHATTER_SCENE.instantiate()
	get_tree().current_scene.add_child(debris)
	debris.global_position = global_position
	
	GameManager.on_enemy_defeated()
	
	visible = false
	collision_layer = 0
	collision_mask = 0
	get_tree().create_timer(0.2).timeout.connect(queue_free)
