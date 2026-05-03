## CardView — 单张卡的 UI 显示（手牌或入队队列中）
class_name CardView
extends PanelContainer

signal card_clicked(card: CardInstance)

@onready var name_label: Label = %Name
@onready var cost_label: Label = %Cost
@onready var frames_label: Label = %Frames
@onready var desc_label: Label = %Desc
@onready var elem_label: Label = %Elem
@onready var btn: Button = %ClickArea

var card: CardInstance

func set_card(c: CardInstance, _interactive: bool) -> void:
	card = c
	# _ready 之前可能被调用，所以等节点就绪
	if not is_node_ready():
		await ready
	var d := c.data
	name_label.text = "%s %s" % [d.intent_icon(), d.display_name]
	cost_label.text = "AP %d" % d.cost
	frames_label.text = "%d / %d / %d" % [d.windup_frames, d.active_frames, d.recovery_frames]
	desc_label.text = d.description
	if d.element == Element.Type.NONE:
		elem_label.text = ""
	else:
		elem_label.text = Element.name_of(d.element)
		elem_label.add_theme_color_override("font_color", Element.color_of(d.element))

func _ready() -> void:
	btn.pressed.connect(_on_click)
	custom_minimum_size = Vector2(140, 200)

func _on_click() -> void:
	card_clicked.emit(card)
