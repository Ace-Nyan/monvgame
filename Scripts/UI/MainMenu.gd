extends Control

@onready var _start_button: Button = $Center/VBox/StartButton
@onready var _encyclopedia_button: Button = $Center/VBox/EncyclopediaButton
@onready var _tutorial_button: Button = $Center/VBox/TutorialButton
@onready var _quit_button: Button = $Center/VBox/QuitButton
@onready var _tutorial_overlay: Control = $TutorialOverlay
@onready var _close_tutorial_button: Button = $TutorialOverlay/Panel/VBox/CloseButton

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_start_button.pressed.connect(_on_start_pressed)
	_encyclopedia_button.pressed.connect(_on_encyclopedia_pressed)
	_tutorial_button.pressed.connect(_on_tutorial_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_close_tutorial_button.pressed.connect(_close_tutorial)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/CharacterSelect.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_encyclopedia_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/Encyclopedia.tscn")

func _on_tutorial_pressed() -> void:
	_tutorial_overlay.visible = true
	_close_tutorial_button.grab_focus()

func _close_tutorial() -> void:
	_tutorial_overlay.visible = false
	_tutorial_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not _tutorial_overlay.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_tutorial()
		get_viewport().set_input_as_handled()
