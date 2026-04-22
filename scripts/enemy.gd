class_name EnemyAI
extends CharacterBody3D

const SPEED_WALK = 3.5
const SPEED_RUN = 6.0
const SPEED_IDLE = 0.0

@export var detection_radius: float = 15.0
@export var attack_range: float = 0.80

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var monster_model: Node3D = $MonsterModel

var monster_scene: Node3D
var animation_player: AnimationPlayer

enum State { IDLE, PATROL, CHASE, ATTACK }
var current_state: State = State.PATROL
var previous_state: State = State.PATROL

var target_player: Node3D
var patrol_points: Array[Vector3] = []
var current_patrol_index: int = 0
var state_timer: float = 0.0
var has_attacked: bool = false

func _ready():
	navigation_agent.path_desired_distance = 1.0
	navigation_agent.target_desired_distance = 0.4
	
	load_monster_model()
	
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

func load_monster_model():
	var monster_scene_path = "res://asssets/characters/monster/mounster1.glb"
	var packed_scene = load(monster_scene_path)
	if packed_scene:
		monster_scene = packed_scene.instantiate()
		monster_model.add_child(monster_scene)
		
		if monster_scene.has_node("AnimationPlayer"):
			animation_player = monster_scene.get_node("AnimationPlayer")
			print("Animaciones disponibles: ", animation_player.get_animation_list())
			play_animation("idle")
		else:
			print("Warning: El modelo no tiene AnimationPlayer")
	else:
		print("Error: No se pudo cargar el modelo del monstruo")

func play_animation(anim_name: String, loop: bool = false, force: bool = false):
	if animation_player:
		var anim_list = animation_player.get_animation_list()
		for anim in anim_list:
			if anim.to_lower().contains(anim_name.to_lower()):
				var is_playing = animation_player.current_animation == anim and animation_player.is_playing()
				if force or not is_playing:
					if loop:
						animation_player.play(anim, -1)
					else:
						animation_player.play(anim)
				return

func process_idle(delta):
	play_animation("idle", false, true)
	
	look_at_player(delta)
	detect_players()
	
	if target_player != null:
		current_state = State.CHASE
		state_timer = 0
		return
	
	state_timer += delta
	if state_timer > 0.5:
		state_timer = 0
		current_state = State.PATROL

func process_patrol(delta):
	play_animation("walk", true, true)
	if !$AudioStreamPlayer3D.playing:
		$AudioStreamPlayer3D.play()
	
	look_at_player(delta)
	
	if target_player != null:
		$AudioStreamPlayer3D.stop()
		current_state = State.CHASE
		return
	
	if patrol_points.size() == 0:
		$AudioStreamPlayer3D.stop()
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
		$AudioStreamPlayer3D.stop()
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()

func look_at_player(delta):
	if target_player == null or not is_instance_valid(target_player):
		return
	
	var player_pos = target_player.global_position
	var direction_to_player = global_position.direction_to(player_pos)
	var target_rotation = Vector2(direction_to_player.x, direction_to_player.z).angle()
	rotation.y = lerp_angle(rotation.y, target_rotation, 15 * delta)

func process_chase(delta):
	play_animation("run", true, true)
	
	if target_player == null or not is_instance_valid(target_player) or target_player.is_dead:
		target_player = null
		has_attacked = false
		current_state = State.IDLE
		return
	
	look_at_player(delta)
	
	var distance_to_player = global_position.distance_to(target_player.global_position)
	
	if distance_to_player <= attack_range:
		current_state = State.ATTACK
		return
	
	var direction = global_position.direction_to(target_player.global_position)
	velocity.x = direction.x * SPEED_RUN
	velocity.z = direction.z * SPEED_RUN
	move_and_slide()

func process_attack(delta):
	$AudioStreamPlayer3D.stop()
	$AudioStreamPlayer3D2.stop()
	if previous_state != current_state:
		play_animation("attack")
		previous_state = current_state
	
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
	
	if global_position.direction_to(target_player.global_position).length() > 0.1:
		var target_rotation = Vector2(target_player.global_position.x - global_position.x, target_player.global_position.z - global_position.z).angle()
		rotation.y = lerp_angle(rotation.y, target_rotation, 10 * delta)
	
	if not has_attacked:
		$AudioStreamPlayer.play()
		await get_tree().create_timer(0.3).timeout
		if is_instance_valid(target_player):
			var dead_player_name = target_player.name
			target_player.sync_death.rpc(dead_player_name)
		has_attacked = true
		print("PLAYER ELIMINADO")
		await get_tree().create_timer(0.5).timeout
		current_state = State.PATROL
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
			$AudioStreamPlayer3D2.play()
			if current_state != State.CHASE and current_state != State.ATTACK:
				current_state = State.CHASE
				has_attacked = false
				print("Player detected! Switching to CHASE")
	elif closest_distance > detection_radius or closest_player == null:
		if current_state == State.CHASE:
			target_player = null
			has_attacked = false
			current_state = State.PATROL

func _physics_process(_delta):
	if not is_multiplayer_authority():
		return
	
	sync_position.rpc(global_position)

@rpc("any_peer")
func sync_position(pos: Vector3):
	if not is_multiplayer_authority():
		global_position = pos
