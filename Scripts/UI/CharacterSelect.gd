extends Control

@onready var _confirm_button: Button = $Panel/VBox/ConfirmButton
@onready var _back_button: Button = $Panel/VBox/BackButton

const CHARACTER_ID: StringName = &"xiaomonv"

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_back_button.pressed.connect(_on_back_pressed)

func _on_confirm_pressed() -> void:
	RunState.select_character(CHARACTER_ID)
	RunState.start_new_run()
	get_tree().change_scene_to_file("res://Scenes/Map/MapScene.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")
