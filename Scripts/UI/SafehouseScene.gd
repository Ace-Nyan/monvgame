extends Control

@onready var _options_root: VBoxContainer = $Root/Options
@onready var _continue_button: Button = $Root/ContinueButton

var _resolved: bool = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_continue_button.pressed.connect(_on_continue_pressed)
	_build_options()

func _build_options() -> void:
	for c in _options_root.get_children():
		c.queue_free()
	var options := [
		{ "text": "休息：生命回复 50%", "action": func(): RunState.apply_heal_percent(0.50) },
		{ "text": "冥想：魔力回复 50%", "action": func(): RunState.apply_mana_percent(0.50) },
		{ "text": "训练：每回合抽牌数 +1", "action": func(): RunState.add_draw_bonus(1) },
	]
	for opt in options:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(320, 44)
		btn.text = opt.text
		btn.pressed.connect(_on_option_pressed.bind(opt.action))
		_options_root.add_child(btn)

func _on_option_pressed(action: Callable) -> void:
	if _resolved:
		return
	_resolved = true
	if action.is_valid():
		action.call()
	for c in _options_root.get_children():
		if c is Button:
			c.disabled = true
	_continue_button.visible = true

func _on_continue_pressed() -> void:
	RunState.complete_current_node()
	get_tree().change_scene_to_file("res://Scenes/Map/MapScene.tscn")
