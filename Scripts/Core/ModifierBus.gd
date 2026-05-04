## ModifierBus — 数值修饰管道（autoload）
##
## 所有"可被修改"的数值读取都过这个总线：
##   final = ModifierBus.compute("enemy_max_hp", base_value, ctx)
##
## 修饰条目结构：
##   { id: StringName, key: StringName, op: 0|1|2, value: float, ctx_filter: Callable|null }
##   op = ADD(0) | MUL(1) | OVERRIDE(2)
##
## 计算顺序：先所有 ADD（按注册序累加），再所有 MUL（连乘），最后 OVERRIDE 覆盖。
## ctx_filter 可选：返回 false 则跳过本次（用于"只对火属性敌人 +HP"等条件修饰）。
##
## 来源（id 命名约定）：
##   "relic:<relic_id>"     收藏品
##   "card:<card_id>"       卡牌持有共鸣
##   "event:<event_id>"     场景/剧情临时
##   "tuning"               GameTuning 默认值（最低优先级，外层用）
extends Node

enum Op { ADD, MUL, OVERRIDE }

var _entries: Array = []                 ## Array[Dictionary]

# === 注册 / 注销 ===

## 注册一条修饰。返回 true 表示成功
func add(id: StringName, key: StringName, op: int, value: float, ctx_filter: Callable = Callable()) -> void:
	_entries.append({
		"id": id,
		"key": key,
		"op": op,
		"value": value,
		"ctx_filter": ctx_filter,
	})
	EventBus.modifier_added.emit(id, key)

## 移除某 id 名下的所有条目（如脱下收藏品、buff 到期）
func remove_by_id(id: StringName) -> void:
	var n_before := _entries.size()
	_entries = _entries.filter(func(e): return e["id"] != id)
	if _entries.size() != n_before:
		EventBus.modifier_removed.emit(id)

func clear() -> void:
	_entries.clear()

# === 计算 ===

func compute(key: StringName, base: float, ctx: Dictionary = {}) -> float:
	var add_sum := 0.0
	var mul_prod := 1.0
	var override_val := NAN
	for e in _entries:
		if e["key"] != key:
			continue
		if e["ctx_filter"].is_valid():
			if not e["ctx_filter"].call(ctx):
				continue
		match e["op"]:
			Op.ADD: add_sum += e["value"]
			Op.MUL: mul_prod *= e["value"]
			Op.OVERRIDE: override_val = e["value"]
	if not is_nan(override_val):
		return override_val
	return (base + add_sum) * mul_prod

func compute_int(key: StringName, base: int, ctx: Dictionary = {}) -> int:
	return int(round(compute(key, float(base), ctx)))

# === 调试 ===

func snapshot() -> Array:
	return _entries.duplicate(true)
