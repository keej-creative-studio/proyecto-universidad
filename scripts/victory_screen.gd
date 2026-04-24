extends Control

var _timer: Timer

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	process_mode = ProcessMode.PROCESS_MODE_ALWAYS
	$VBoxContainer/MenuPrincipal.grab_focus()
	
	_timer = Timer.new()
	_timer.wait_time = 5.0
	_timer.one_shot = true
	_timer.timeout.connect(_on_menu_principal_pressed)
	add_child(_timer)
	_timer.start()

func _input(event) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_menu_principal_pressed()

func _on_menu_principal_pressed() -> void:
	if _timer:
		_timer.stop()
		_timer.queue_free()
	_queue_free_victory_screen()
	NetworkManager.disconnect_from_game()

func _queue_free_victory_screen() -> void:
	queue_free()
