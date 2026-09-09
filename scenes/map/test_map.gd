extends Node3D

## TestMap Scene for "Very Hot"
## Lightweight, high performance map setup with clean minimalist materials and real-time graphics settings.

const MAP_GLTF_SCENE: PackedScene = preload("res://assets/models/map/VH_TestMap.gltf")

@onready var map_container: Node3D = $MapContainer
@onready var player_spawn: Marker3D = $PlayerSpawn
@onready var enemy_spawn: Marker3D = $EnemySpawn
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var dir_light: DirectionalLight3D = $DirectionalLight3D

var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D

func _ready() -> void:
	_create_materials()
	_instance_map()
	GameManager.apply_graphics_to_current_scene(world_env, dir_light)
	GameManager.graphics_settings_changed.connect(_on_graphics_changed)

func _on_graphics_changed() -> void:
	GameManager.apply_graphics_to_current_scene(world_env, dir_light)

func _create_materials() -> void:
	floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.92, 0.93, 0.95, 1.0)
	floor_material.roughness = 0.35
	floor_material.metallic = 0.05
	
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.85, 0.86, 0.88, 1.0)
	wall_material.roughness = 0.45
	wall_material.metallic = 0.02

func _instance_map() -> void:
	var map_inst = MAP_GLTF_SCENE.instantiate()
	map_container.add_child(map_inst)
	_apply_materials_only(map_inst)

func _apply_materials_only(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst: MeshInstance3D = node as MeshInstance3D
		var node_name = mesh_inst.name.to_lower()
		if "плоскость" in node_name or "floor" in node_name or "plane" in node_name:
			mesh_inst.material_override = floor_material
		else:
			mesh_inst.material_override = wall_material
	
	for child in node.get_children():
		_apply_materials_only(child)
