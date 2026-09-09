extends Area3D

## Slow-motion Bullet with SUPERHOT-style trail
## Moves smoothly in world space.

@export var speed: float = 16.0
@export var damage: int = 35
@export var is_from_player: bool = false
@export var max_lifetime: float = 8.0

var direction: Vector3 = Vector3.FORWARD
var lifetime: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(spawn_pos: Vector3, dir: Vector3, from_player: bool) -> void:
	global_position = spawn_pos
	direction = dir.normalized()
	is_from_player = from_player
	if from_player:
		damage = 100
		speed = 22.0
	else:
		damage = 35
		speed = 15.0
	
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
			queue_free()
	else:
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
			queue_free()
		elif not body.is_in_group("enemy"):
			queue_free()

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("punch_hitbox") and not is_from_player:
		SoundManager.play_hit()
		queue_free()
