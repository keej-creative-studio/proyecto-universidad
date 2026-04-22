extends Control

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	process_mode = ProcessMode.PROCESS_MODE_ALWAYS
	$VBoxContainer/MenuPrincipal.grab_focus()

func _input(event) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_menu_principal_pressed()

func _on_menu_principal_pressed() -> void:
	NetworkManager.disconnect_from_game()
