extends Node

@export var required_delivery: int = 6
@export var carry_limit: int = 2
@export var pickup_range: float = 4.0
@export var deposit_range: float = 4.0
@export var partygoer_path: NodePath = NodePath("../Sketchfab_Scene2")
@export var hud_label_path: NodePath = NodePath("HUD/Control/ObjectiveLabel")
@export var carry_label_path: NodePath = NodePath("HUD/Control/CarryLabel")

const VICTORY_SCENE := preload("res://scenes/Victory.tscn")

var player_carried: Dictionary = {}
var collected_objects: Dictionary = {}
var delivered_total: int = 0
var victory_shown: bool = false
var game_ended: bool = false

@onready var hud_label: Label = get_node_or_null(hud_label_path) as Label
@onready var carry_label: Label = get_node_or_null(carry_label_path) as Label

func request_interact(player_name: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_rpc_request_interact.rpc_id(1, player_name)
		return

	_handle_interact(player_name)

@rpc("any_peer", "reliable")
func _rpc_request_interact(player_name: String) -> void:
	_handle_interact(player_name)

func _handle_interact(player_name: String) -> void:
	if victory_shown:
		return

	var player: Player = _find_player(player_name)
	if player == null or player.is_dead:
		return

	var carried := int(player_carried.get(player_name, 0))
	var partygoer := get_node_or_null(partygoer_path) as Node3D
	if partygoer and player.global_position.distance_to(partygoer.global_position) <= deposit_range and carried > 0:
		_deposit(player_name, carried)
		return

	if carried >= carry_limit:
		return

	var collectible := _find_nearest_collectible(player.global_position)
	if collectible == null:
		return

	var collectible_name := collectible.name
	if bool(collected_objects.get(collectible_name, false)):
		return

	_pickup(player_name, collectible_name)

func _pickup(player_name: String, collectible_name: String) -> void:
	collected_objects[collectible_name] = true
	var carried := int(player_carried.get(player_name, 0)) + 1
	player_carried[player_name] = carried
	_broadcast_state(player_name, collectible_name, carried, delivered_total, true)

func _deposit(player_name: String, amount: int) -> void:
	player_carried[player_name] = 0
	delivered_total += amount
	_broadcast_state(player_name, "", 0, delivered_total, false)

@rpc("authority", "call_local", "reliable")
func _sync_state(player_name: String, collectible_name: String, carried: int, delivered: int, picked: bool) -> void:
	player_carried[player_name] = carried
	delivered_total = delivered

	if picked and collectible_name != "":
		_set_collectible_visible(collectible_name, false)

	_update_hud()
	if delivered_total >= required_delivery and not victory_shown:
		victory_shown = true
		_show_victory()

func _broadcast_state(player_name: String, collectible_name: String, carried: int, delivered: int, picked: bool) -> void:
	if multiplayer.has_multiplayer_peer():
		_sync_state.rpc(player_name, collectible_name, carried, delivered, picked)
	else:
		_sync_state(player_name, collectible_name, carried, delivered, picked)

func _set_collectible_visible(collectible_name: String, state: bool) -> void:
	for collectible in get_tree().get_nodes_in_group("collectible_dollface"):
		if collectible is Node3D and collectible.name == collectible_name:
			collectible.visible = state
			break

func _find_nearest_collectible(player_position: Vector3) -> Node3D:
	var nearest: Node3D = null
	var nearest_distance: float = INF

	for collectible in get_tree().get_nodes_in_group("collectible_dollface"):
		if not (collectible is Node3D):
			continue
		var collectible_node := collectible as Node3D
		if not collectible_node.visible:
			continue

		var distance := collectible_node.global_position.distance_to(player_position)
		if distance <= pickup_range and distance < nearest_distance:
			nearest = collectible_node
			nearest_distance = distance

	return nearest

func _find_player(player_name: String) -> Player:
	for player in get_tree().get_nodes_in_group("player"):
		if player is Player and str(player.name) == player_name:
			return player
	return null

func _update_hud() -> void:
	if hud_label:
		hud_label.text = "Recolectados: %d/%d" % [delivered_total, required_delivery]

	if carry_label:
		var local_player_name := str(multiplayer.get_unique_id())
		var carried := int(player_carried.get(local_player_name, 0))
		carry_label.text = "Llevas: %d/%d" % [carried, carry_limit]

func _show_victory() -> void:
	end_game()
	var victory := VICTORY_SCENE.instantiate()
	get_tree().root.add_child(victory)

func end_game() -> void:
	game_ended = true
	set_process(false)
