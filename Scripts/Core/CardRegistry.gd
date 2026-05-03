## CardRegistry — 卡牌目录（autoload）
##
## 启动时扫描 res://Data/Cards/*.tres 并注册到字典。
## 玩家自定义卡也可放入 user://Cards/，由 register_user_cards() 加载。
extends Node

const CARD_DIR := "res://Data/Cards"
const USER_CARD_DIR := "user://Cards"

var _cards: Dictionary = {}   ## id -> CardData

func _ready() -> void:
	_scan_dir(CARD_DIR)
	_scan_dir(USER_CARD_DIR)

func _scan_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
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
