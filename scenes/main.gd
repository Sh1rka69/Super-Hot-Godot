extends Node3D

## Main Scene for "Very Hot"
## Spawns the Map, Player, Enemy, HUD, and Mobile Controls.

@onready var test_map = $TestMap
@onready var player = $Player
@onready var enemy = $Enemy
@onready var hud = $HUD
@onready var mobile_controls = $MobileControls
@onready var pause_menu = $PauseMenu

func _ready() -> void:
	_position_entities()
	_connect_pause()

func _position_entities() -> void:
	if test_map and player:
		var p_spawn = test_map.get_node_or_null("PlayerSpawn")
		if p_spawn:
			player.global_transform = p_spawn.global_transform
	
	if test_map and enemy:
		var e_spawn = test_map.get_node_or_null("EnemySpawn")
		if e_spawn:
			enemy.global_transform = e_spawn.global_transform

func _connect_pause() -> void:
	if mobile_controls and pause_menu:
		mobile_controls.pause_requested.connect(pause_menu.toggle_pause)
