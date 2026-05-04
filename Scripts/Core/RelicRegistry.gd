## RelicRegistry — 收藏品注册中心（autoload）
##
## 职责：
##   - 启动时扫描 Data/Relics/*.tres + user://Relics/*.tres 注册可用收藏品定义
##   - 玩家拾取时调用 collect(id) → 把 RelicData.modifiers 注入 ModifierBus
##   - 失去时 drop(id) → 从 ModifierBus 反注册
extends Node

const BUILT_IN_DIR := "res://Data/Relics/"
const USER_DIR := "user://Relics/"

var _defs: Dictionary = {}                       ## id -> RelicData
var _owned: Dictionary = {}                      ## id -> RelicData

signal relic_collected(relic: RelicData)
signal relic_dropped(relic: RelicData)

func _ready() -> void:
	_scan_dir(BUILT_IN_DIR)
	if DirAccess.dir_exists_absolute(USER_DIR):
		_scan_dir(USER_DIR)

func _scan_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".tres"):
			var res := load(dir_path + name)
			if res is RelicData and res.id != &"":
				_defs[res.id] = res
		name = dir.get_next()

func get_def(id: StringName) -> RelicData:
	return _defs.get(id, null)

func all_defs() -> Array:
	return _defs.values()

func owned() -> Array:
	return _owned.values()

func has_relic(id: StringName) -> bool:
	return _owned.has(id)

# === 拾取 / 丢弃 ===

func collect(id: StringName) -> bool:
	var def := get_def(id)
	if def == null or _owned.has(id):
		return false
	_owned[id] = def
	_apply_modifiers(def)
	relic_collected.emit(def)
	return true

func drop(id: StringName) -> bool:
	if not _owned.has(id):
		return false
	var def: RelicData = _owned[id]
	_owned.erase(id)
	ModifierBus.remove_by_id(_modifier_id(def))
	relic_dropped.emit(def)
	return true

# === 内部 ===

func _modifier_id(def: RelicData) -> StringName:
	return StringName("relic:" + String(def.id))

func _apply_modifiers(def: RelicData) -> void:
	var mid := _modifier_id(def)
	for m in def.modifiers:
		var op_str: String = m.get("op", "mul")
		var op: int
		match op_str:
			"add": op = ModifierBus.Op.ADD
			"override": op = ModifierBus.Op.OVERRIDE
			_: op = ModifierBus.Op.MUL
		var key: StringName = m.get("key", &"")
		var value: float = float(m.get("value", 1.0))
		var filter_enemy_id: StringName = m.get("filter_enemy_id", &"")
		var filter: Callable = Callable()
		if filter_enemy_id != &"":
			filter = func(ctx): return ctx.get("enemy_id", &"") == filter_enemy_id
		ModifierBus.add(mid, key, op, value, filter)
