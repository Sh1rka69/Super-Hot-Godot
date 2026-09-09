extends Node3D

## Spawns red crystal shards on enemy death/shatter

@export var shard_count: int = 14
var lifetime: float = 4.0

func _ready() -> void:
	_spawn_shards()
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _spawn_shards() -> void:
	var crystal_mat = StandardMaterial3D.new()
	crystal_mat.albedo_color = Color(1.0, 0.08, 0.04, 1.0)
	crystal_mat.roughness = 0.15
	crystal_mat.metallic = 0.2
	crystal_mat.emission_enabled = true
	crystal_mat.emission = Color(0.85, 0.05, 0.0)
	crystal_mat.emission_energy_multiplier = 0.6
	
	for i in range(shard_count):
		var body = RigidBody3D.new()
		body.collision_layer = 0
		body.collision_mask = 1
		body.mass = 0.3
		
		var col = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		var s_size = randf_range(0.08, 0.22)
		box_shape.size = Vector3(s_size, s_size * randf_range(0.8, 1.8), s_size)
		col.shape = box_shape
		body.add_child(col)
		
		var mesh_inst = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = box_shape.size
		box_mesh.material = crystal_mat
		mesh_inst.mesh = box_mesh
		body.add_child(mesh_inst)
		
		# Offset position across enemy body height (0.2m to 1.8m)
		var spawn_offset = Vector3(
			randf_range(-0.35, 0.35),
			randf_range(0.2, 1.7),
			randf_range(-0.35, 0.35)
		)
		body.position = spawn_offset
		
		add_child(body)
		
		# Outward blast impulse
		var impulse = (spawn_offset.normalized() + Vector3(0, 0.5, 0) + Vector3(randf_range(-0.5, 0.5), randf_range(0, 0.5), randf_range(-0.5, 0.5))).normalized() * randf_range(3.0, 7.0)
		body.apply_central_impulse(impulse)
		body.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
