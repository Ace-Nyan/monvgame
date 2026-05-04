extends Control

@onready var _options_root: VBoxContainer = $Root/Options
@onready var _continue_button: Button = $Root/ContinueButton

var _resolved: bool = false
var _offered: Array[RelicData] = []

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_continue_button.pressed.connect(_on_continue_pressed)
	_build_options()

func _build_options() -> void:
	for c in _options_root.get_children():
		c.queue_free()
	_offered.clear()
	for i in range(2):
		var r: RelicData = RelicManager.draw_from_wish_pool()
		_offered.append(r)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(360, 52)
		btn.text = "%s" % r.display_name
		btn.pressed.connect(_on_option_pressed.bind(r))
		_options_root.add_child(btn)

func _on_option_pressed(relic: RelicData) -> void:
	if _resolved:
		return
	_resolved = true
	RelicManager.add_relic(relic)
	for c in _options_root.get_children():
		if c is Button:
			c.disabled = true
	_continue_button.visible = true

func _on_continue_pressed() -> void:
	RunState.complete_current_node()
	get_tree().change_scene_to_file("res://Scenes/Map/MapScene.tscn")
