extends Node3D

@export var generate_colliders: bool = false
@export var wait_time: float = 1.0

func _ready() -> void:
	if generate_colliders:
		await get_tree().create_timer(wait_time).timeout
		generate_wall_colliders()

func generate_wall_colliders() -> void:
	print("=== Generando colliders para LEVEL ===")
	
	var level_node = get_parent()
	if not level_node:
		push_error("No se encontro el nodo padre (LEVEL)")
		return
	
	var meshes = _find_all_meshes(level_node)
	print("Mallas encontradas: ", meshes.size())
	
	for mesh_data in meshes:
		_create_collider_for_mesh(mesh_data.node, mesh_data.mesh)

func _find_all_meshes(node: Node) -> Array:
	var result: Array = []
	_find_meshes_recursive(node, result)
	return result

func _find_meshes_recursive(node: Node, result: Array) -> void:
	if node is MeshInstance3D and node.mesh:
		result.append({"node": node, "mesh": node.mesh})
	
	for child in node.get_children():
		_find_meshes_recursive(child, result)

func _create_collider_for_mesh(node: Node, mesh: Mesh) -> void:
	if not mesh or not node:
		return
	
	print("Creando collider para: ", node.name)
	
	var static_body = StaticBody3D.new()
	static_body.name = "Collider_" + node.name
	node.add_child(static_body)
	
	var collision_shape = CollisionShape3D.new()
	static_body.add_child(collision_shape)
	
	var shape = _create_convex_shape(mesh)
	if shape:
		collision_shape.shape = shape
		print("  -> Collider creado!")
	else:
		print("  -> Fallo al crear shape")

func _create_convex_shape(mesh: Mesh) -> ConvexPolygonShape3D:
	if not mesh:
		return null
	
	var faces: PackedVector3Array = mesh.get_faces()
	if faces.is_empty():
		return null
	
	var unique_vertices: Array = []
	var tolerance = 0.0001
	
	for vertex in faces:
		var is_unique = true
		for existing in unique_vertices:
			if existing.distance_to(vertex) < tolerance:
				is_unique = false
				break
		if is_unique:
			unique_vertices.append(vertex)
	
	var shape = ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array(unique_vertices)
	return shape
