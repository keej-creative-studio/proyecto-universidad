extends Node3D

@export var dollface_scene: PackedScene = preload("res://asssets/found_obj/backrooms_entity_34_dollfaces_wikidot.glb")
@export var spawn_count: int = 12
@export var min_distance: float = 8.0
@export var spawn_area_size: Vector2 = Vector2(120.0, 90.0)
@export var ray_origin_height: float = 80.0
@export var ray_length: float = 220.0
@export var surface_offset: float = 0.05
@export var seed: int = 1337
@export var spawn_delay: float = 1.5
@export var dollface_scale: Vector3 = Vector3(0.01, 0.01, 0.01)

# 🔦 Luz estilo terror
@export var spotlight_color: Color = Color(1.0, 0.85, 0.7, 1.0)
@export var spotlight_energy: float = 10.0
@export var spotlight_range: float = 15.0
@export var spotlight_spot_angle: float = 35.0
@export var spotlight_activation_distance: float = 25.0

@export var anchor_path: NodePath = NodePath("../MapSpawnPoint")

var spawned_dollfaces: Array[Node3D] = []
var spawned_spotlights: Array[SpotLight3D] = []

func _ready() -> void:
	await get_tree().create_timer(spawn_delay).timeout
	_spawn_dollfaces()

func _process(_delta: float) -> void:
	_update_spotlights()

func _spawn_dollfaces() -> void:
	if dollface_scene == null:
		push_error("No se pudo cargar el modelo de dollface")
		return

	var anchor: Node3D = get_node_or_null(anchor_path) as Node3D
	var center: Vector3 = anchor.global_position if anchor else global_position

	var rng := RandomNumberGenerator.new()
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed

	var placed_positions: Array[Vector3] = []
	var space_state := get_world_3d().direct_space_state

	for i in spawn_count:
		var spawn_position: Variant = _find_spawn_position(rng, center, space_state, placed_positions)
		if spawn_position == null:
			continue

		var instance := dollface_scene.instantiate() as Node3D
		if instance == null:
			continue

		instance.name = "Dollface_%02d" % (i + 1)
		instance.add_to_group("collectible_dollface")
		add_child(instance)
		instance.scale = dollface_scale
		instance.global_position = spawn_position as Vector3

		var light := _add_spotlight(instance)

		spawned_dollfaces.append(instance)
		spawned_spotlights.append(light)
		placed_positions.append(spawn_position)

func _find_spawn_position(rng: RandomNumberGenerator, center: Vector3, space_state: PhysicsDirectSpaceState3D, placed_positions: Array[Vector3]) -> Variant:
	for _attempt in 30:
		var candidate_x = center.x + rng.randf_range(-spawn_area_size.x * 0.5, spawn_area_size.x * 0.5)
		var candidate_z = center.z + rng.randf_range(-spawn_area_size.y * 0.5, spawn_area_size.y * 0.5)

		var ray_from = Vector3(candidate_x, center.y + ray_origin_height, candidate_z)
		var ray_to = ray_from + Vector3.DOWN * ray_length

		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		query.collision_mask = 1

		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			continue

		var spawn_position: Vector3 = hit.position + Vector3.UP * surface_offset
		if _is_far_enough(spawn_position, placed_positions):
			return spawn_position

	return null

func _is_far_enough(candidate: Vector3, placed_positions: Array[Vector3]) -> bool:
	for position in placed_positions:
		if position.distance_to(candidate) < min_distance:
			return false
	return true

# 🔥 SPOTLIGHT CORRECTO
func _add_spotlight(target: Node3D) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.name = "DollfaceSpotLight"
	light.light_color = spotlight_color
	light.light_energy = spotlight_energy
	light.spot_range = spotlight_range
	light.spot_angle = spotlight_spot_angle

	# ✅ PRIMERO añadir al árbol (evita error)
	add_child(light)

	# 📍 Posición global (arriba y enfrente del muñeco)
	var offset := Vector3(0.0, 3.0, 2.0)
	light.global_position = target.global_position + offset

	# 🎯 Apuntar al muñeco
	light.look_at(target.global_position, Vector3.UP)

	# ⚠️ Corrección de dirección típica
	light.rotate_x(deg_to_rad(180))

	# 🌑 Sombras para efecto terror
	light.shadow_enabled = true

	light.visible = false
	return light

# 🔥 ACTIVACIÓN CORRECTA
func _update_spotlights() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_set_all_spotlights(false)
		return

	var player := players[0] as Node3D
	if not is_instance_valid(player):
		return

	for i in spawned_dollfaces.size():
		var dollface := spawned_dollfaces[i]
		var light := spawned_spotlights[i]

		if not is_instance_valid(dollface) or not is_instance_valid(light):
			continue

		var dist := dollface.global_position.distance_to(player.global_position)

		# 🔦 Encender/apagar
		light.visible = dist <= spotlight_activation_distance

		# 🎯 Mantener apuntando
		if light.visible:
			light.look_at(dollface.global_position, Vector3.UP)

func _set_all_spotlights(state: bool) -> void:
	for light in spawned_spotlights:
		if is_instance_valid(light):
			light.visible = state
