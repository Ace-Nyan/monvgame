extends Node
class_name RelicBar

@export var bar_path: NodePath
@export var tooltip_path: NodePath

var _bar: HBoxContainer
var _tooltip: Control
var _name_label: Label
var _desc_label: Label
var _effect_label: Label

func _ready() -> void:
	_bar = get_node_or_null(bar_path) as HBoxContainer
	_tooltip = get_node_or_null(tooltip_path) as Control
	if _tooltip:
		_name_label = _tooltip.get_node_or_null("VBox/Name") as Label
		_desc_label = _tooltip.get_node_or_null("VBox/Desc") as Label
		_effect_label = _tooltip.get_node_or_null("VBox/Effect") as Label
	if RelicManager:
		RelicManager.relics_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	if _bar == null:
		return
	for c in _bar.get_children():
		c.queue_free()
	if RelicManager.relics.is_empty():
		var placeholder := Label.new()
		placeholder.text = "遗物"
		placeholder.modulate = Color(1, 1, 1, 0.5)
		_bar.add_child(placeholder)
		_on_hover_exit()
		return
	for r in RelicManager.relics:
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.color = r.icon_color
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.mouse_entered.connect(_on_hover.bind(r))
		icon.mouse_exited.connect(_on_hover_exit)
		_bar.add_child(icon)
	_on_hover_exit()

func _on_hover(r: RelicData) -> void:
	if _tooltip == null:
		return
	if _name_label:
		_name_label.text = r.display_name
	if _desc_label:
		_desc_label.text = r.description
	if _effect_label:
		_effect_label.text = r.effect_text
	_tooltip.visible = true

func _on_hover_exit() -> void:
	if _tooltip:
		_tooltip.visible = false
