## CardRegistry — 卡牌目录（autoload）
##
## 启动时显式加载内置卡牌资源并注册到字典。
## 玩家自定义卡也可放入 user://Cards/，由 register_user_cards() 加载。
extends Node

const USER_CARD_DIR := "user://Cards"
const BUILTIN_CARDS := [
	preload("res://Data/Cards/defend.tres"),
	preload("res://Data/Cards/delirium.tres"),
	preload("res://Data/Cards/fireball.tres"),
	preload("res://Data/Cards/magic_barrage.tres"),
	preload("res://Data/Cards/magic_manual.tres"),
	preload("res://Data/Cards/mana_boost.tres"),
	preload("res://Data/Cards/quick_jab.tres"),
	preload("res://Data/Cards/riposte.tres"),
	preload("res://Data/Cards/roll.tres"),
	preload("res://Data/Cards/slime_damage_up.tres"),
	preload("res://Data/Cards/slime_water_cannon.tres"),
	preload("res://Data/Cards/slime_water_shot.tres"),
	preload("res://Data/Cards/strike.tres"),
	preload("res://Data/Cards/vine_whip.tres"),
	preload("res://Data/Cards/water_jet.tres"),
	preload("res://Data/Cards/weakness_curse.tres"),
	preload("res://Data/Cards/witch_form.tres"),
	preload("res://Data/Cards/witch_judgement.tres"),
	preload("res://Data/Cards/witch_touch.tres"),
]

var _cards: Dictionary = {}   ## id -> CardData

func _ready() -> void:
	_load_builtin_cards()
	_scan_dir(USER_CARD_DIR)

func _load_builtin_cards() -> void:
	for card in BUILTIN_CARDS:
		if card is CardData:
			register(card)

func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".tres"):
			var res := load(path + "/" + f)
			if res is CardData:
				register(res)
		f = dir.get_next()
	dir.list_dir_end()

func register(card: CardData) -> void:
	if card.id == &"":
		push_warning("CardData missing id: %s" % card.resource_path)
		return
	_cards[card.id] = card

func get_card(id: StringName) -> CardData:
	return _cards.get(id, null)

func all_ids() -> Array:
	return _cards.keys()
