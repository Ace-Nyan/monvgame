extends Control

@onready var _gold_label: Label = $Root/GoldLabel
@onready var _grid: GridContainer = $Root/Grid
@onready var _leave_button: Button = $Root/LeaveButton

const SLOT_COUNT: int = 6

var _items: Array = []
var _buttons: Array[Button] = []

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_leave_button.pressed.connect(_on_leave_pressed)
	_build_items()
	_refresh_gold()

func _build_items() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_items.clear()
	_buttons.clear()
	var relic_slots: int = 3
	var card_slots: int = 3
	for i in range(relic_slots):
		_items.append(_pick_shop_relic(i))
	for i in range(card_slots):
		_items.append(_pick_shop_card())
	for item in _items:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 72)
		btn.text = item.label
		btn.pressed.connect(_on_item_pressed.bind(item))
		_grid.add_child(btn)
		_buttons.append(btn)
	_refresh_buttons()

func _pick_shop_relic(index: int) -> Dictionary:
	var use_rare: bool = index == 0
	var relic: RelicData = RelicManager.draw_from_shop_pool(use_rare)
	var price := _relic_price(relic)
	return {"type": "relic", "relic": relic, "price": price, "label": "%s\n%d魔法币" % [relic.display_name, price], "purchased": false}

func _pick_shop_card() -> Dictionary:
	var pool := RunState.card_pool_ids
	if pool.is_empty():
		pool = CardRegistry.all_ids()
	var id: StringName = pool[randi() % pool.size()]
	var card: CardData = CardRegistry.get_card(id)
	var price := _card_price(card)
	return {"type": "card", "card": card, "price": price, "label": "%s\n%d魔法币" % [card.display_name, price], "purchased": false}

func _card_price(card: CardData) -> int:
	if card == null:
		return 4
	match card.rarity:
		CardData.Rarity.WHITE: return 4
		CardData.Rarity.BLUE: return 8
		CardData.Rarity.GOLD: return 12
	return 4

func _relic_price(relic: RelicData) -> int:
	if relic == null:
		return 8
	match relic.category:
		RelicData.Category.LOW: return 8
		RelicData.Category.MID: return 16
		RelicData.Category.HIGH: return 24
		RelicData.Category.SHOP: return 24
	return 16

func _refresh_gold() -> void:
	_gold_label.text = "魔法币: %d" % RunState.gold

func _on_item_pressed(item: Dictionary) -> void:
	if item.purchased:
		return
	var price: int = item.price
	if RunState.gold < price:
		return
	RunState.gold -= price
	if item.type == "relic":
		RelicManager.add_relic(item.relic)
	else:
		RunState.add_card_to_deck(item.card)
	item.purchased = true
	_refresh_buttons()
	_refresh_gold()

func _refresh_buttons() -> void:
	for i in range(_items.size()):
		var item: Dictionary = _items[i]
		var btn: Button = _buttons[i]
		if item.purchased:
			btn.disabled = true
			btn.text = "已购买"
		else:
			btn.disabled = false
			btn.text = item.label

func _on_leave_pressed() -> void:
	RunState.complete_current_node()
	get_tree().change_scene_to_file("res://Scenes/Map/MapScene.tscn")
