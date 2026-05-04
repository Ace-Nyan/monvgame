extends CanvasLayer

@export var capture_mouse_on_resume: bool = false

@onready var _panel: Control = $Overlay/Panel
@onready var _continue_button: Button = $Overlay/Panel/VBox/ContinueButton
@onready var _main_menu_button: Button = $Overlay/Panel/VBox/MainMenuButton
@onready var _quit_button: Button = $Overlay/Panel/VBox/QuitButton

var _is_open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_continue_button.pressed.connect(_resume_game)
	_main_menu_button.pressed.connect(_return_to_main_menu)
	_quit_button.pressed.connect(_quit_game)

func _exit_tree() -> void:
	if _is_open:
		get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	if _is_open:
		_resume_game()
	else:
		_open_menu()

func _open_menu() -> void:
	_is_open = true
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_continue_button.grab_focus()

func _resume_game() -> void:
	_is_open = false
	visible = false
	get_tree().paused = false
	if capture_mouse_on_resume:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _return_to_main_menu() -> void:
	_is_open = false
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")

func _quit_game() -> void:
	_is_open = false
	visible = false
	get_tree().paused = false
	get_tree().quit()
