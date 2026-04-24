class_name Player extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var _player_input : PlayerInput
@export var _camera_input : CameraInput
@export var _player_model : Node3D
@export var _state_machine: RewindableStateMachine

@onready var rollback_synchronizer = $RollbackSynchronizer

var _animation_player
var is_dead: bool = false:
	set(v):
		is_dead = v
		if is_dead:
			visible = false
			collision_layer = 0
			collision_mask = 0
		else:
			visible = true
			collision_layer = 1
			collision_mask = 1

var _game_over_instance: Node = null
var _is_local_player: bool = false

func _enter_tree():
	var peer_id = str(name).to_int()
	_player_input.set_multiplayer_authority(peer_id)
	_camera_input.set_multiplayer_authority(peer_id)
	add_to_group("player")

func _ready():
	_state_machine.state = &"IdleState"
	_animation_player = _player_model.get_node("AnimationPlayer")
	_state_machine.on_display_state_changed.connect(_on_display_state_changed)
	rollback_synchronizer.process_settings()
	
	var my_peer_id = multiplayer.get_unique_id()
	var player_peer = str(name).to_int()
	_is_local_player = (my_peer_id == player_peer)
	
	if _is_local_player:
		NetworkManager.hide_loading()

func _process(_delta: float) -> void:
	if not _is_local_player or is_dead:
		return

	if Input.is_action_just_pressed("interact"):
		var objectives = get_tree().current_scene.get_node_or_null("GameObjectives")
		if objectives:
			objectives.request_interact(str(name))

func show_game_over():
	if _game_over_instance != null and is_instance_valid(_game_over_instance):
		return
	
	if not _is_local_player:
		return
	
	var game_over_scene = load("res://scenes/GameOver.tscn")
	var instance = game_over_scene.instantiate()
	instance.player_peer_id = str(name).to_int()
	instance.player_name = str(name)
	_game_over_instance = instance
	get_tree().root.add_child(instance)
	
func _game_ended_check() -> bool:
	var objectives = get_tree().current_scene.get_node_or_null("GameObjectives")
	if objectives and "game_ended" in objectives and objectives.game_ended:
		return true
	return false

func die():
	if is_dead:
		return
	
	if _game_ended_check():
		return
	
	is_dead = true
	print("DIE LLAMADO - Mi peer: ", multiplayer.get_unique_id(), " Mi nombre: ", name)
	
	if _animation_player and _animation_player.has_animation("death"):
		_animation_player.play("death")
	
	show_game_over()

@rpc("any_peer", "call_local")
func request_death():
	pass

func _on_killed_by_enemy():
	die()

@rpc("any_peer", "call_local")
func sync_death(dead_player_name: String):
	if is_dead:
		return
	if str(name) != dead_player_name:
		return
	die()

func respawn():
	print("RESPAWN - Mi peer: ", multiplayer.get_unique_id(), " Mi nombre: ", name)
	sync_respawn.rpc(str(name))
	is_dead = false
	velocity = Vector3.ZERO
	_game_over_instance = null
	global_position = Vector3(randi_range(-2, 2), 1, randi_range(-2, 2))
	_state_machine.state = &"IdleState"

@rpc("any_peer", "call_local")
func sync_respawn(player_name: String):
	print("SYNC RESPAWN - player_name: ", player_name, " - mi nombre: ", name, " - is_dead: ", is_dead)
	if str(name) == player_name:
		print("  -> Reviviendo a este jugador")
		is_dead = false

func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	if is_dead:
		return
	_force_update_is_on_floor()
	if not is_on_floor():
		apply_gravity(delta)

func _on_display_state_changed(old_state, new_state):
	var animation_name = new_state.animation_name
	if _animation_player && animation_name != "":
		_animation_player.play(animation_name)

func apply_gravity(delta):
	velocity.y -= gravity * delta
				
func _force_update_is_on_floor():
	if is_dead:
		return
	var old_velocity = velocity
	velocity *= 0
	move_and_slide()
	velocity = old_velocity
