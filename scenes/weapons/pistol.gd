extends RigidBody3D

## Pistol Weapon for "Very Hot"
## Thread-safe, deferred parenting to prevent physics callback lockups.

signal fired(ammo_left: int)

@export var max_ammo: int = 4
var current_ammo: int = 4
var is_equipped: bool = false
var is_thrown: bool = false
var throw_damage: int = 100

@onready var muzzle: Marker3D = $Muzzle
@onready var muzzle_flash: OmniLight3D = $Muzzle/MuzzleFlash
@onready var pickup_area: Area3D = $PickupArea
@onready var mesh_root: Node3D = $MeshRoot

const BULLET_SCENE: PackedScene = preload("res://scenes/weapons/bullet.tscn")

func _ready() -> void:
	if muzzle_flash:
		muzzle_flash.visible = false
	if pickup_area:
		pickup_area.body_entered.connect(_on_pickup_body_entered)

func equip_to_hand(parent_node: Node3D) -> void:
	is_equipped = true
	is_thrown = false
	set_deferred("freeze", true)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if pickup_area:
		pickup_area.set_deferred("monitoring", false)
	
	_reparent_to_hand.call_deferred(parent_node)

func _reparent_to_hand(parent_node: Node3D) -> void:
	if not is_instance_valid(parent_node):
		return
	if get_parent():
		get_parent().remove_child(self)
	parent_node.add_child(self)
	transform = Transform3D.IDENTITY

func drop_or_throw(from_transform: Transform3D, throw_impulse: Vector3) -> void:
	is_equipped = false
	_reparent_to_world.call_deferred(from_transform, throw_impulse)

func _reparent_to_world(from_transform: Transform3D, throw_impulse: Vector3) -> void:
	set_deferred("freeze", false)
	set_deferred("collision_layer", 2)
	set_deferred("collision_mask", 1)
	if pickup_area:
		pickup_area.set_deferred("monitoring", true)
	
	var world_tree = get_tree().current_scene
	if get_parent():
		get_parent().remove_child(self)
	if is_instance_valid(world_tree):
		world_tree.add_child(self)
	global_transform = from_transform
	
	if throw_impulse != Vector3.ZERO:
		is_thrown = true
		linear_velocity = throw_impulse
		angular_velocity = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
	else:
		linear_velocity = Vector3.ZERO

func shoot(shoot_dir: Vector3, from_player: bool) -> bool:
	if current_ammo <= 0:
		return false
	
	current_ammo -= 1
	SoundManager.play_shoot()
	
	if muzzle_flash:
		muzzle_flash.visible = true
		var tween = create_tween()
		tween.tween_property(muzzle_flash, "visible", false, 0.05)
	
	var bullet = BULLET_SCENE.instantiate()
	var spawn_pos: Vector3 = muzzle.global_position if muzzle else global_position
	get_tree().current_scene.add_child(bullet)
	bullet.setup(spawn_pos, shoot_dir, from_player)
	
	fired.emit(current_ammo)
	return true

func _on_pickup_body_entered(body: Node3D) -> void:
	if is_equipped:
		return
	if is_thrown:
		if body.is_in_group("enemy") and body.has_method("take_hit"):
			body.take_hit(global_position, linear_velocity.normalized())
			SoundManager.play_hit()
			is_thrown = false
	if body.is_in_group("player") and body.has_method("try_pickup_weapon"):
		body.try_pickup_weapon(self)
