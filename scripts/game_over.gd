extends Control

@export var player_peer_id: int = 0
@export var player_name: String = ""

var my_peer_id: int
var btn_reiniciar: Button
var btn_salir: Button

func _ready():
	my_peer_id = multiplayer.get_unique_id()
	print("GameOver - Mi peer ID: ", my_peer_id, " | Murió: ", player_peer_id, " | Nombre: ", player_name)
	
	if my_peer_id != player_peer_id:
		queue_free()
		return
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	process_mode = ProcessMode.PROCESS_MODE_ALWAYS
	
	modulate = Color(1, 1, 1, 0)
	$ColorRect.modulate = Color(0, 0, 0, 7)
	
	btn_reiniciar = $VBoxContainer/Reiniciar
	btn_salir = $VBoxContainer/Salir
	btn_reiniciar.focus_mode = Control.FOCUS_ALL
	btn_salir.focus_mode = Control.FOCUS_ALL
	_update_exit_state()
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 1.5)
	tween.tween_property($ColorRect, "modulate:a", 1.0, 1.5)
	
	await get_tree().create_timer(1.0).timeout
	btn_reiniciar.grab_focus()

func _process(_delta: float) -> void:
	_update_exit_state()

func _update_exit_state() -> void:
	if btn_salir == null:
		return

	btn_salir.disabled = not _can_exit()


func _can_exit() -> bool:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() <= 1:
		return true

	for player in players:
		if player is Player and not player.is_dead:
			return false
	return true

func _input(event):
	if event.is_action_pressed("ui_accept"):
		_on_reiniciar_pressed()
	elif event.is_action_pressed("ui_cancel"):
		_on_salir_pressed()

func _on_reiniciar_pressed():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("REINICIAR presionado - player_name: ", player_name)
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		print("  Jugador: ", player.name)
		if str(player.name) == player_name:
			print("  Encontrado! Llamando respawn")
			player.respawn()
			break
	queue_free()

func _on_salir_pressed():
	if not _can_exit():
		return
	print("SALIR presionado")
	queue_free()
	NetworkManager.disconnect_from_game()
