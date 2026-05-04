extends Node

signal relics_changed

const BUILTIN_RELICS := [
	preload("res://Data/Relics/ancient_wand.tres"),
	preload("res://Data/Relics/archmage_wand.tres"),
	preload("res://Data/Relics/broom.tres"),
	preload("res://Data/Relics/cursed_anklet.tres"),
	preload("res://Data/Relics/king_ring.tres"),
	preload("res://Data/Relics/new_wand.tres"),
	preload("res://Data/Relics/old_wand.tres"),
	preload("res://Data/Relics/red_scarf.tres"),
	preload("res://Data/Relics/strange_wand.tres"),
	preload("res://Data/Relics/witch_hat.tres"),
	preload("res://Data/Relics/witch_hat_upgraded.tres"),
	preload("res://Data/Relics/witch_potion.tres"),
	preload("res://Data/Relics/witch_tears.tres"),
]

var relics: Array[RelicData] = []

var _relic_by_id: Dictionary = {}
var _discovered_ids: Dictionary = {}
var _pool_low: Array[RelicData] = []
var _pool_mid: Array[RelicData] = []
var _pool_high: Array[RelicData] = []
var _pool_shop: Array[RelicData] = []
var _pool_event: Array[RelicData] = []
var _pool_starter: Array[RelicData] = []
var _pool_unique: Array[RelicData] = []

var _wish_pool_ids: Array[StringName] = []

var _broom_id: StringName = &"broom"

func _ready() -> void:
	_load_all_relics()

func reset_run() -> void:
	relics.clear()
	_build_pools()
	relics_changed.emit()

func _load_all_relics() -> void:
	_relic_by_id.clear()
	for res in BUILTIN_RELICS:
		if res is RelicData:
			var r: RelicData = res
			_relic_by_id[r.id] = r
	_build_pools()

func _build_pools() -> void:
	_pool_low.clear()
	_pool_mid.clear()
	_pool_high.clear()
	_pool_shop.clear()
	_pool_event.clear()
	_pool_starter.clear()
	_pool_unique.clear()
	_wish_pool_ids.clear()
	for r in _relic_by_id.values():
		match r.category:
			RelicData.Category.LOW:
				_pool_low.append(r)
				_wish_pool_ids.append(r.id)
			RelicData.Category.MID:
				_pool_mid.append(r)
				_wish_pool_ids.append(r.id)
			RelicData.Category.HIGH:
				_pool_high.append(r)
			RelicData.Category.SHOP:
				_pool_shop.append(r)
			RelicData.Category.EVENT:
				_pool_event.append(r)
			RelicData.Category.STARTER:
				_pool_starter.append(r)
			RelicData.Category.UNIQUE:
				_pool_unique.append(r)

func add_relic(relic: RelicData) -> void:
	if relic == null:
		return
	if _is_relic_blocked(relic.id):
		return
	relics.append(relic)
	_discovered_ids[relic.id] = true
	_apply_relic_effect(relic)
	_relics_remove_from_pools(relic)
	relics_changed.emit()

func add_relic_by_id(id: StringName) -> void:
	add_relic(get_relic(id))

func get_relic(id: StringName) -> RelicData:
	return _relic_by_id.get(id, null)

func get_relics_by_category(category: int) -> Array[RelicData]:
	var out: Array[RelicData] = []
	for r in _relic_by_id.values():
		if r.category == category:
			out.append(r)
	return out

func get_all_relics() -> Array[RelicData]:
	var out: Array[RelicData] = []
	for r in _relic_by_id.values():
		out.append(r)
	return out

func get_discovered_relics() -> Array[RelicData]:
	var out: Array[RelicData] = []
	for id in _discovered_ids.keys():
		var r := get_relic(id)
		if r:
			out.append(r)
	return out

func draw_from_wish_pool() -> RelicData:
	if _wish_pool_ids.is_empty():
		return get_relic(_broom_id)
	var idx := randi() % _wish_pool_ids.size()
	var id: StringName = _wish_pool_ids[idx]
	_wish_pool_ids.remove_at(idx)
	return get_relic(id)

func draw_from_shop_pool(use_high_or_shop: bool) -> RelicData:
	var pools: Array[Array] = []
	if use_high_or_shop:
		pools = [_pool_high, _pool_shop]
	else:
		pools = [_pool_low, _pool_mid]
	var bag: Array[RelicData] = []
	for p in pools:
		for r in p:
			bag.append(r)
	if bag.is_empty():
		if use_high_or_shop:
			return draw_from_shop_pool(false)
		return get_relic(_broom_id)
	var pick := bag[randi() % bag.size()]
	_relics_remove_from_pools(pick)
	return pick

func _relics_remove_from_pools(relic: RelicData) -> void:
	if relic == null:
		return
	if relic.id == _broom_id:
		return
	_pool_low.erase(relic)
	_pool_mid.erase(relic)
	_pool_high.erase(relic)
	_pool_shop.erase(relic)
	_pool_event.erase(relic)
	_pool_starter.erase(relic)
	_pool_unique.erase(relic)
	_wish_pool_ids.erase(relic.id)

func _apply_relic_effect(relic: RelicData) -> void:
	if relic == null:
		return
	match relic.id:
		&"red_scarf":
			RunState.max_hp += 10
			RunState.hp = clampi(RunState.hp + 5, 0, RunState.max_hp)
		&"king_ring":
			RunState.keep_block = true
		&"broom":
			RunState.max_hp += 1
			RunState.hp = clampi(RunState.hp, 0, RunState.max_hp)
		&"witch_hat":
			RunState.relic_witch_hat = true
		&"witch_tears":
			RunState.relic_witch_tears = true
		&"cursed_anklet":
			RunState.replace_cards(&"magic_manual", &"witch_form")
		&"old_wand":
			var removed := RunState.remove_random_element()
			if removed != Element.Type.NONE:
				RunState.remove_cards_by_element(removed, 5)
		&"ancient_wand":
			var removed := RunState.remove_random_element()
			if removed != Element.Type.NONE:
				RunState.remove_cards_by_element(removed, -1)
		&"new_wand":
			var added := RunState.add_random_element()
			if added != Element.Type.NONE:
				RunState.add_cards_by_element(added, 5)
		&"strange_wand":
			var result := RunState.replace_random_element()
			var removed_elem: int = result.removed
			if removed_elem != Element.Type.NONE:
				RunState.remove_cards_by_element(removed_elem, -1)
		&"archmage_wand":
			var result := RunState.replace_random_element()
			var removed_elem: int = result.removed
			if removed_elem != Element.Type.NONE:
				RunState.remove_cards_by_element(removed_elem, -1)
				_add_random_group_by_element(removed_elem, 5)
		&"witch_potion":
			RunState.replace_random_element()
			RunState.replace_random_element()
			var curse := CardRegistry.get_card(&"delirium")
			for i in 5:
				RunState.add_card_to_deck(curse)
		_:
			pass

func _add_random_group_by_element(element: int, count: int) -> void:
	var pool: Array[CardData] = []
	for id in CardRegistry.all_ids():
		var c := CardRegistry.get_card(id)
		if c and c.element == element:
			pool.append(c)
	if pool.is_empty():
		return
	pool.shuffle()
	for i in count:
		var pick := pool[randi() % pool.size()]
		RunState.add_card_to_deck(pick)

func _is_relic_blocked(id: StringName) -> bool:
	if id == &"old_wand" and _has_relic(&"ancient_wand"):
		return true
	if id == &"ancient_wand" and _has_relic(&"old_wand"):
		return true
	if id == &"strange_wand" and _has_relic(&"archmage_wand"):
		return true
	if id == &"archmage_wand" and _has_relic(&"strange_wand"):
		return true
	return false

func _has_relic(id: StringName) -> bool:
	for r in relics:
		if r.id == id:
			return true
	return false
