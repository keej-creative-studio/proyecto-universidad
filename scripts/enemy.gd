class_name EnemyAI
extends CharacterBody3D

const SPEED_WALK = 3.5
const SPEED_RUN = 6.0
const SPEED_IDLE = 0.0

@export var detection_radius: float = 15.0
@export var attack_range: float = 0.80

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

enum State { IDLE, PATROL, CHASE, ATTACK }
var current_state: State = State.IDLE

var target_player: Node3D
var patrol_points: Array[Vector3] = []
var current_patrol_index: int = 0
var state_timer: float = 0.0
var has_attacked: bool = false

func _ready():
	navigation_agent.path_desired_distance = 1.0
	navigation_agent.target_desired_distance = 0.4
	
	patrol_points = [
		Vector3(10, 1, 10),
		Vector3(-10, 1, 10),
		Vector3(-10, 1, -10),
		Vector3(10, 1, -10)
	]

func _enter_tree():
	add_to_group("enemy")

func _process(delta):
	if current_state != State.ATTACK:
		detect_players()
	
	match current_state:
		State.IDLE:
			process_idle(delta)
		State.PATROL:
			process_patrol(delta)
		State.CHASE:
			process_chase(delta)
		State.ATTACK:
			process_attack(delta)

func process_idle(delta):
	state_timer += delta
	if state_timer > 2.0:
		state_timer = 0
		current_state = State.PATROL

func process_patrol(delta):
	if patrol_points.size() == 0:
		current_state = State.IDLE
		return
	
	var target = patrol_points[current_patrol_index]
	navigation_agent.target_position = target
	
	if not navigation_agent.is_navigation_finished():
		var direction = global_position.direction_to(navigation_agent.get_next_path_position())
		velocity.x = direction.x * SPEED_WALK
		velocity.z = direction.z * SPEED_WALK
		move_and_slide()
	else:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()

func process_chase(delta):
	if target_player == null or not is_instance_valid(target_player) or target_player.is_dead:
		target_player = null
		has_attacked = false
		current_state = State.IDLE
		return
	
	var distance_to_player = global_position.distance_to(target_player.global_position)
	
	if distance_to_player <= attack_range:
		current_state = State.ATTACK
		return
	
	navigation_agent.target_position = target_player.global_position
	
	if not navigation_agent.is_navigation_finished():
		var direction = global_position.direction_to(navigation_agent.get_next_path_position())
		velocity.x = direction.x * SPEED_RUN
		velocity.z = direction.z * SPEED_RUN
		move_and_slide()
		
	look_at(Vector3(target_player.global_position.x, global_position.y, target_player.global_position.z), Vector3.UP)

func process_attack(delta):
	if target_player == null or not is_instance_valid(target_player) or target_player.is_dead:
		target_player = null
		has_attacked = false
		current_state = State.IDLE
		return
	
	var distance_to_player = global_position.distance_to(target_player.global_position)
	
	if distance_to_player > attack_range:
		current_state = State.CHASE
		has_attacked = false
		return
	
	velocity = Vector3.ZERO
	look_at(Vector3(target_player.global_position.x, global_position.y, target_player.global_position.z), Vector3.UP)
	
	if not has_attacked:
		$AudioStreamPlayer.play()
		var dead_player_name = target_player.name
		target_player.sync_death.rpc(dead_player_name)
		has_attacked = true
		print("PLAYER ELIMINADO")
		current_state = State.IDLE
		target_player = null

func detect_players():
	var players = get_tree().get_nodes_in_group("player")
	var closest_player = null
	var closest_distance = INF
	
	for player in players:
		if player == self:
			continue
		if player.is_dead or not player.visible:
			continue
		var dist = global_position.distance_to(player.global_position)
		if dist < closest_distance:
			closest_distance = dist
			closest_player = player
	
	if closest_player != null and closest_distance <= detection_radius:
		if target_player == null or target_player != closest_player:
			target_player = closest_player
			if current_state != State.CHASE and current_state != State.ATTACK:
				current_state = State.CHASE
				has_attacked = false
				print("Player detected! Switching to CHASE")
	elif closest_distance > detection_radius or closest_player == null:
		if current_state == State.CHASE:
			current_state = State.IDLE
			target_player = null
			has_attacked = false

func _physics_process(_delta):
	if not is_multiplayer_authority():
		return
	
	sync_position.rpc(global_position)

@rpc("any_peer")
func sync_position(pos: Vector3):
	if not is_multiplayer_authority():
		global_position = pos
