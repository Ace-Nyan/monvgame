extends Control

@onready var _continue_button: Button = $Root/ContinueButton
@onready var _gold_label: Label = $Root/GoldLabel

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_continue_button.pressed.connect(_on_continue_pressed)
	_gold_label.text = "魔法币 +%d" % RunState.last_reward_gold

func _on_continue_pressed() -> void:
	RunState.complete_current_node()
	get_tree().change_scene_to_file("res://Scenes/Map/MapScene.tscn")
