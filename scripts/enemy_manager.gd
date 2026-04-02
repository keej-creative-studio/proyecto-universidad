class_name EnemyManager
extends Node

@export var enemy_scene: PackedScene
@export var player_scene: PackedScene

@onready var navigation_region: NavigationRegion3D = $"../NavigationRegion3D"

func _ready():
	await get_tree().create_timer(2.0).timeout
	spawn_enemy()

func spawn_enemy():
	var enemy = enemy_scene.instantiate()
	enemy.position = Vector3(10, 1, 10)
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		enemy.set_target(players[0])
	
	add_child(enemy)
	
	# Rebake navigation after spawning enemy
	await get_tree().create_timer(0.5).timeout
	navigation_region.bake_navigation_mesh()

func _process(_delta):
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var enemies = get_tree().get_nodes_in_group("enemy")
		for enemy in enemies:
			enemy.set_target(players[0])