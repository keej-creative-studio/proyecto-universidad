extends Control

@export var player_peer_id: int = 0
@export var player_name: String = ""

var my_peer_id: int

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
	
	var btn_reiniciar = $VBoxContainer/Reiniciar
	var btn_salir = $VBoxContainer/Salir
	btn_reiniciar.focus_mode = Control.FOCUS_ALL
	btn_salir.focus_mode = Control.FOCUS_ALL
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 1.5)
	tween.tween_property($ColorRect, "modulate:a", 1.0, 1.5)
	
	await get_tree().create_timer(1.0).timeout
	btn_reiniciar.grab_focus()

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
	print("SALIR presionado")
	queue_free()
	NetworkManager.disconnect_from_game()
