# RunState.gd
# 全局游戏流程状态（自动加载）
extends Node

const NODE_BATTLE: StringName = &"battle"
const NODE_ELITE: StringName = &"elite"
const NODE_EVENT: StringName = &"event"
const NODE_SAFEHOUSE: StringName = &"safehouse"
const NODE_WISH: StringName = &"wish"
const NODE_SHOP: StringName = &"shop"

var route: Array[StringName] = []
var current_index: int = 0

var max_hp: int = 60
var hp: int = 60
var max_mp: int = 30
var mp: int = 30
var base_def: int = 0
var base_res: int = 10
var gold: int = 10
var keep_block: bool = false

var player_deck_ids: Array[StringName] = []
var card_pool_ids: Array[StringName] = []
var common_card_pool_ids: Array[StringName] = []
var character_card_pool_ids: Array[StringName] = []
var last_reward_gold: int = 0

var draw_bonus: int = 0

var selected_character_id: StringName = &""
var character_magic_elements: Array[int] = []

var relic_witch_hat: bool = false
var turn_witch_hat_fire_mult: float = 0.0
var turn_witch_hat_water_used: bool = false
var relic_witch_tears: bool = false

var pending_encounter: Dictionary = {}
var current_encounter: Dictionary = {}
var encyclopedia_mode: String = ""

const CHARACTER_XIAOMONV: StringName = &"xiaomonv"
const WITCH_POOL_IDS: Array[StringName] = [
	&"fireball",
	&"magic_barrage",
	&"witch_touch",
	&"magic_manual",
	&"witch_form",
	&"witch_judgement",
	&"mana_boost",
]

const ENEMY_WATER_SLIME: StringName = &"N001"
const ENCOUNTER_DEFAULT: String = "遭遇"
const ENCOUNTER_SURF: String = "滑水"

func start_new_run() -> void:
	route = _build_route()
	current_index = 0
	_apply_character_setup()
	hp = max_hp
	mp = max_mp
	gold = 10
	keep_block = false
	last_reward_gold = 0
	draw_bonus = 0
	relic_witch_hat = false
	relic_witch_tears = false
	pending_encounter.clear()
	current_encounter.clear()
	reset_turn_bonuses()
	var relic_mgr := get_node_or_null("/root/RelicManager")
	if relic_mgr:
		relic_mgr.reset_run()
		if selected_character_id == CHARACTER_XIAOMONV:
			relic_mgr.add_relic_by_id(&"witch_hat")

func select_character(character_id: StringName) -> void:
	selected_character_id = character_id
	_apply_character_setup()

func reset_turn_bonuses() -> void:
	turn_witch_hat_fire_mult = 0.0
	turn_witch_hat_water_used = false

func _apply_character_setup() -> void:
	if selected_character_id == &"":
		selected_character_id = CHARACTER_XIAOMONV
	match selected_character_id:
		CHARACTER_XIAOMONV:
			max_hp = 60
			max_mp = 30
			base_def = 0
			base_res = 10
			character_magic_elements = [Element.Type.FIRE, Element.Type.WATER, Element.Type.GRASS]
			player_deck_ids = _build_xiaomonv_starting_deck()
			character_card_pool_ids = WITCH_POOL_IDS.duplicate()
			common_card_pool_ids = _build_common_pool(WITCH_POOL_IDS)
			_rebuild_card_pools()
		_:
			character_magic_elements.clear()
			player_deck_ids.clear()
			character_card_pool_ids.clear()
			common_card_pool_ids = _build_common_pool([])
			_rebuild_card_pools()

func _build_common_pool(exclude_ids: Array[StringName]) -> Array[StringName]:
	var pool: Array[StringName] = []
	if CardRegistry:
		var raw: Array = CardRegistry.all_ids()
		for id in raw:
			var sid := StringName(id)
			if exclude_ids.has(sid):
				continue
			pool.append(sid)
	return pool

func _build_element_pool(elements: Array[int]) -> Array[StringName]:
	var pool: Array[StringName] = []
	if CardRegistry == null:
		return pool
	for id in CardRegistry.all_ids():
		var card := CardRegistry.get_card(id)
		if card and elements.has(card.element):
			pool.append(StringName(id))
	return pool

func _filtered_character_pool_ids() -> Array[StringName]:
	var pool: Array[StringName] = []
	for id in character_card_pool_ids:
		var card := CardRegistry.get_card(id)
		if card == null:
			continue
		if card.element == Element.Type.NONE or character_magic_elements.has(card.element):
			pool.append(id)
	return pool

func _rebuild_card_pools() -> void:
	var bag: Dictionary = {}
	for id in common_card_pool_ids:
		bag[id] = true
	for id in _filtered_character_pool_ids():
		bag[id] = true
	for id in _build_element_pool(character_magic_elements):
		bag[id] = true
	card_pool_ids.clear()
	for id in bag.keys():
		card_pool_ids.append(StringName(id))

func get_common_pool_ids() -> Array[StringName]:
	return _build_common_pool(WITCH_POOL_IDS)

func get_character_pool_ids(character_id: StringName) -> Array[StringName]:
	if character_id == CHARACTER_XIAOMONV:
		return WITCH_POOL_IDS.duplicate()
	return []

func _build_xiaomonv_starting_deck() -> Array[StringName]:
	return [
		&"magic_barrage",
		&"magic_manual",
		&"witch_touch",
		&"fireball",
		&"fireball",
		&"fireball",
		&"fireball",
		&"roll",
		&"roll",
		&"defend",
		&"defend",
		&"mana_boost",
	]

func _build_route() -> Array[StringName]:
	var nodes: Array[StringName] = [NODE_BATTLE, NODE_ELITE, NODE_EVENT, NODE_SAFEHOUSE, NODE_WISH, NODE_SHOP]
	nodes.shuffle()
	return nodes

func current_node_type() -> StringName:
	if current_index < 0 or current_index >= route.size():
		return &""
	return route[current_index]

func is_route_complete() -> bool:
	return current_index >= route.size()

func complete_current_node() -> void:
	current_index += 1

func apply_heal_percent(pct: float) -> void:
	var amount := int(round(float(max_hp) * pct))
	hp = clampi(hp + amount, 0, max_hp)

func apply_mana_percent(pct: float) -> void:
	var amount := int(round(float(max_mp) * pct))
	mp = clampi(mp + amount, 0, max_mp)

func add_draw_bonus(amount: int) -> void:
	draw_bonus = maxi(0, draw_bonus + amount)

func add_card_to_deck(card: CardData) -> void:
	if card == null:
		return
	player_deck_ids.append(card.id)

func remove_cards_by_element(element: int, count: int) -> void:
	var remaining := count
	var i := player_deck_ids.size() - 1
	while i >= 0:
		var id := player_deck_ids[i]
		var card := CardRegistry.get_card(id)
		if card and card.element == element:
			player_deck_ids.remove_at(i)
			if remaining > 0:
				remaining -= 1
				if remaining == 0:
					return
		i -= 1

func add_cards_by_element(element: int, count: int) -> void:
	var pool: Array[StringName] = []
	for id in CardRegistry.all_ids():
		var card := CardRegistry.get_card(id)
		if card and card.element == element:
			pool.append(StringName(id))
	if pool.is_empty():
		return
	for i in count:
		player_deck_ids.append(pool[randi() % pool.size()])

func replace_cards(old_id: StringName, new_id: StringName) -> void:
	var count := 0
	for id in player_deck_ids:
		if id == old_id:
			count += 1
	player_deck_ids = player_deck_ids.filter(func(x): return x != old_id)
	for i in count:
		player_deck_ids.append(new_id)

func remove_random_element() -> int:
	if character_magic_elements.is_empty():
		return Element.Type.NONE
	var idx := randi() % character_magic_elements.size()
	var elem := character_magic_elements[idx]
	character_magic_elements.remove_at(idx)
	_rebuild_card_pools()
	return elem

func add_random_element() -> int:
	var candidates: Array[int] = [Element.Type.FIRE, Element.Type.WATER, Element.Type.GRASS]
	for e in character_magic_elements:
		candidates.erase(e)
	if candidates.is_empty():
		return Element.Type.NONE
	var elem := candidates[randi() % candidates.size()]
	character_magic_elements.append(elem)
	_rebuild_card_pools()
	return elem

func replace_random_element() -> Dictionary:
	var removed := remove_random_element()
	var added := add_random_element()
	return {"removed": removed, "added": added}

func prepare_encounter_for_node(node_type: StringName) -> void:
	if node_type != NODE_BATTLE and node_type != NODE_ELITE:
		pending_encounter.clear()
		return
	var encounter_name := ENCOUNTER_DEFAULT
	if randi() % 2 == 0:
		encounter_name = ENCOUNTER_SURF
	pending_encounter = _build_encounter(encounter_name)

func confirm_pending_encounter() -> void:
	current_encounter = pending_encounter.duplicate(true)

func get_current_encounter() -> Dictionary:
	if current_encounter.is_empty() and not pending_encounter.is_empty():
		return pending_encounter
	return current_encounter

func _build_encounter(name: String) -> Dictionary:
	match name:
		ENCOUNTER_SURF:
			return _build_surf_encounter()
		_:
			return {
				"name": ENCOUNTER_DEFAULT,
				"variant": "标准",
				"enemies": [
					{"id": ENEMY_WATER_SLIME, "count": 1, "spawn": "start"}
				]
			}

func _build_surf_encounter() -> Dictionary:
	var roll := randi() % 3
	if roll == 0:
		return {
			"name": ENCOUNTER_SURF,
			"variant": "标准",
			"enemies": [
				{"id": ENEMY_WATER_SLIME, "count": 2, "spawn": "start"}
			]
		}
	if roll == 1:
		return {
			"name": ENCOUNTER_SURF,
			"variant": "变种1",
			"enemies": [
				{"id": ENEMY_WATER_SLIME, "count": 3, "spawn": "start"}
			]
		}
	return {
		"name": ENCOUNTER_SURF,
		"variant": "变种2",
		"enemies": [
			{"id": ENEMY_WATER_SLIME, "count": 2, "spawn": "start"},
			{"id": ENEMY_WATER_SLIME, "count": 1, "spawn": "after_clear"}
		]
	}

func get_enemy_info(id: StringName) -> Dictionary:
	if id == ENEMY_WATER_SLIME:
		return {
			"id": "N001",
			"name": "水史莱姆",
			"stats": "生命30 防御0 法抗30",
			"traits": "免疫水属性伤害",
			"attack": "策略1 水弹(8点水属性) / 策略2 伤害+2(永久)",
			"defense": "策略1 攻击牌触发随机跳跃(2次) / 策略2 水炮准备"
		}
	return {}

func get_enemy_catalog() -> Array[Dictionary]:
	return [get_enemy_info(ENEMY_WATER_SLIME)]

func get_enemy_scene(id: StringName) -> PackedScene:
	if id == ENEMY_WATER_SLIME:
		return load("res://Scenes/Enemies/WaterSlime.tscn")
	return null
