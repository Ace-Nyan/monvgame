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
		{ "text": "拾取药剂：生命 +15%", "action": func(): RunState.apply_heal_percent(0.15) },
		{ "text": "冥想片刻：魔力 +15%", "action": func(): RunState.apply_mana_percent(0.15) },
		{ "text": "冒险调查：生命 -10%，抽牌 +1", "action": func(): _risk_reward() },
	]
	options.shuffle()
	for i in 3:
		var opt = options[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(320, 44)
		btn.text = opt.text
		btn.pressed.connect(_on_option_pressed.bind(opt.action))
		_options_root.add_child(btn)

func _risk_reward() -> void:
	RunState.apply_heal_percent(-0.10)
	RunState.add_draw_bonus(1)

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
