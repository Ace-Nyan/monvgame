extends Control

@onready var _common_button: Button = $Root/Tabs/CommonButton
@onready var _witch_button: Button = $Root/Tabs/WitchButton
@onready var _enemy_button: Button = $Root/Tabs/EnemyButton
@onready var _relic_button: Button = $Root/Tabs/RelicButton
@onready var _relic_filters: HBoxContainer = $Root/RelicFilters
@onready var _debug_all: CheckBox = $Root/RelicFilters/DebugAll
@onready var _relic_all: Button = $Root/RelicFilters/AllRelics
@onready var _relic_low: Button = $Root/RelicFilters/LowRelics
@onready var _relic_mid: Button = $Root/RelicFilters/MidRelics
@onready var _relic_high: Button = $Root/RelicFilters/HighRelics
@onready var _relic_shop: Button = $Root/RelicFilters/ShopRelics
@onready var _relic_event: Button = $Root/RelicFilters/EventRelics
@onready var _relic_starter: Button = $Root/RelicFilters/StarterRelics
@onready var _relic_unique: Button = $Root/RelicFilters/UniqueRelics
@onready var _list: VBoxContainer = $Root/Content/ListScroll/List
@onready var _detail_title: Label = $Root/Content/Detail/DetailVBox/DetailTitle
@onready var _detail_body: Label = $Root/Content/Detail/DetailVBox/DetailBody
@onready var _back_button: Button = $Root/Bottom/BackButton

var _current_cards: Array[CardData] = []
var _mode: String = "cards"

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_common_button.pressed.connect(_show_common)
	_witch_button.pressed.connect(_show_witch)
	_enemy_button.pressed.connect(_show_enemy_placeholder)
	_relic_button.pressed.connect(_show_relics_all)
	_relic_all.pressed.connect(_show_relics_all)
	_relic_low.pressed.connect(_show_relics_low)
	_relic_mid.pressed.connect(_show_relics_mid)
	_relic_high.pressed.connect(_show_relics_high)
	_relic_shop.pressed.connect(_show_relics_shop)
	_relic_event.pressed.connect(_show_relics_event)
	_relic_starter.pressed.connect(_show_relics_starter)
	_relic_unique.pressed.connect(_show_relics_unique)
	_debug_all.toggled.connect(_on_debug_toggled)
	_back_button.pressed.connect(_on_back_pressed)
	_relic_filters.visible = false
	if RunState.encyclopedia_mode == "enemies":
		RunState.encyclopedia_mode = ""
		_show_enemy_placeholder()
	else:
		_show_common()

func _show_common() -> void:
	_mode = "cards"
	_relic_filters.visible = false
	var ids := RunState.get_common_pool_ids()
	_show_cards(_ids_to_cards(ids))

func _show_witch() -> void:
	_mode = "cards"
	_relic_filters.visible = false
	var ids := RunState.get_character_pool_ids(RunState.CHARACTER_XIAOMONV)
	_show_cards(_ids_to_cards(ids))

func _show_enemy_placeholder() -> void:
	_mode = "enemies"
	_relic_filters.visible = false
	_clear_list()
	_current_cards.clear()
	var enemies := RunState.get_enemy_catalog()
	if enemies.is_empty():
		_detail_title.text = "敌人"
		_detail_body.text = "预留中"
		return
	for info in enemies:
		var btn := Button.new()
		btn.text = String(info.get("name", "敌人"))
		btn.pressed.connect(_on_enemy_pressed.bind(info))
		_list.add_child(btn)
	_set_enemy_detail(enemies[0])

func _on_enemy_pressed(info: Dictionary) -> void:
	_set_enemy_detail(info)

func _set_enemy_detail(info: Dictionary) -> void:
	_detail_title.text = String(info.get("name", ""))
	_detail_body.text = _enemy_detail_text(info)

func _enemy_detail_text(info: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("编号: %s" % info.get("id", ""))
	lines.append("属性: %s" % info.get("stats", ""))
	lines.append("特性: %s" % info.get("traits", ""))
	lines.append("攻击: %s" % info.get("attack", ""))
	lines.append("防御: %s" % info.get("defense", ""))
	return "\n".join(lines)

func _show_relics_all() -> void:
	_show_relics_by_category(-1)

func _show_relics_low() -> void:
	_show_relics_by_category(RelicData.Category.LOW)

func _show_relics_mid() -> void:
	_show_relics_by_category(RelicData.Category.MID)

func _show_relics_high() -> void:
	_show_relics_by_category(RelicData.Category.HIGH)

func _show_relics_shop() -> void:
	_show_relics_by_category(RelicData.Category.SHOP)

func _show_relics_event() -> void:
	_show_relics_by_category(RelicData.Category.EVENT)

func _show_relics_starter() -> void:
	_show_relics_by_category(RelicData.Category.STARTER)

func _show_relics_unique() -> void:
	_show_relics_by_category(RelicData.Category.UNIQUE)

func _show_relics_by_category(category: int) -> void:
	_mode = "relics"
	_relic_filters.visible = true
	_clear_list()
	var relics: Array[RelicData] = []
	if _debug_all.button_pressed:
		if category < 0:
			relics = RelicManager.get_all_relics()
		else:
			relics = RelicManager.get_relics_by_category(category)
	else:
		var discovered := RelicManager.get_discovered_relics()
		if category < 0:
			relics = discovered
		else:
			for r in discovered:
				if r.category == category:
					relics.append(r)
	if relics.is_empty():
		_detail_title.text = ""
		_detail_body.text = ""
		return
	for r in relics:
		var btn := Button.new()
		btn.text = r.display_name
		btn.pressed.connect(_on_relic_pressed.bind(r))
		_list.add_child(btn)
	_set_relic_detail(relics[0])

func _on_relic_pressed(relic: RelicData) -> void:
	_set_relic_detail(relic)

func _set_relic_detail(relic: RelicData) -> void:
	if relic == null:
		return
	_detail_title.text = relic.display_name
	_detail_body.text = _relic_detail_text(relic)

func _relic_detail_text(relic: RelicData) -> String:
	var lines: Array[String] = []
	lines.append("类别: %s" % _relic_category_name(relic.category))
	if relic.description != "":
		lines.append("描述: %s" % relic.description)
	if relic.effect_text != "":
		lines.append("效果: %s" % relic.effect_text)
	return "\n".join(lines)

func _relic_category_name(category: int) -> String:
	match category:
		RelicData.Category.LOW: return "低阶"
		RelicData.Category.MID: return "中阶"
		RelicData.Category.HIGH: return "高阶"
		RelicData.Category.SHOP: return "商店"
		RelicData.Category.EVENT: return "事件"
		RelicData.Category.STARTER: return "初始"
		RelicData.Category.UNIQUE: return "唯一"
	return "未知"

func _on_debug_toggled(_pressed: bool) -> void:
	if _mode == "relics":
		_show_relics_all()

func _show_cards(cards: Array[CardData]) -> void:
	_clear_list()
	_current_cards = cards
	if cards.is_empty():
		_detail_title.text = ""
		_detail_body.text = ""
		return
	for card in cards:
		var btn := Button.new()
		btn.text = card.display_name
		btn.pressed.connect(_on_card_pressed.bind(card))
		_list.add_child(btn)
	_set_detail(cards[0])

func _ids_to_cards(ids: Array[StringName]) -> Array[CardData]:
	var cards: Array[CardData] = []
	for id in ids:
		var c := CardRegistry.get_card(id)
		if c:
			cards.append(c)
	return cards

func _on_card_pressed(card: CardData) -> void:
	_set_detail(card)

func _set_detail(card: CardData) -> void:
	if card == null:
		return
	_detail_title.text = card.display_name
	_detail_body.text = _card_detail_text(card)

func _card_detail_text(card: CardData) -> String:
	var lines: Array[String] = []
	lines.append("能耗: %d" % card.cost)
	lines.append("属性: %s" % Element.name_of(card.element))
	var attack_type := "近战" if card.projectile_scene == null else "远程"
	lines.append("攻击方式: %s" % attack_type)
	lines.append("射程: %.1f" % card.range_m)
	var damage := 0
	for e: CardEffect in card.effects:
		if e is DamageEffect:
			var dmg: DamageEffect = e
			damage += dmg.amount
	if damage > 0:
		lines.append("伤害: %d" % damage)
	if card.description != "":
		lines.append("描述: %s" % card.description)
	var effect_lines: Array[String] = []
	for e: CardEffect in card.effects:
		var d := e.describe()
		if d != "":
			effect_lines.append(d)
	if effect_lines.size() > 0:
		lines.append("效果: %s" % "; ".join(effect_lines))
	return "\n".join(lines)

func _clear_list() -> void:
	for c in _list.get_children():
		c.queue_free()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")
