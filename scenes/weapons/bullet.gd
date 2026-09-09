extends Area3D

## Slow-motion Bullet with SUPERHOT-style trail
## Travels through 3D space, damages target on collision.

@export var speed: float = 24.0
@export var damage: int = 100
@export var is_from_player: bool = false
@export var max_lifetime: float = 8.0

var direction: Vector3 = Vector3.FORWARD
var lifetime: float = 0.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var trail_mesh: MeshInstance3D = $TrailMesh

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(spawn_pos: Vector3, dir: Vector3, from_player: bool) -> void:
	global_position = spawn_pos
	direction = dir.normalized()
	is_from_player = from_player
	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime += delta
	if lifetime >= max_lifetime:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if is_from_player:
		if body.is_in_group("enemy"):
			if body.has_method("take_hit"):
				body.take_hit(global_position, direction)
			queue_free()
		elif not body.is_in_group("player"):
			# Hit wall or static geometry
			queue_free()
	else:
		# Bullet from enemy
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
			queue_free()
		elif not body.is_in_group("enemy"):
			# Hit wall or obstacle
			queue_free()

func _on_area_entered(area: Area3D) -> void:
	# Check if bullet collided with another bullet or melee punch hitbox
	if area.is_in_group("punch_hitbox") and not is_from_player:
		# Player punched the bullet out of the air!
		SoundManager.play_hit()
		queue_free()
