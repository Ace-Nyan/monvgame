# CharacterData.gd
@tool
extends Resource
class_name CharacterData

# ==== 基础属性 ====
@export var character_name: String = "新角色"
@export var character_id: String = ""

# 魔法类型标签（数组，因为可以有多个）
@export var magic_types: Array[MagicType.Type] = []

# ==== 基础数值 ====
# 当前值
@export var current_hp: float = 100
@export var current_mp: float = 50
@export var current_ep: float = 3

# 最大值的初始值
@export var base_max_hp: float = 100
@export var base_def: float = 10
@export var base_res: float = 10
@export var base_max_mp: float = 50
@export var base_max_ep: float = 3

# ==== Buff/Debuff 数值 ====
@export var shield: float = 0
@export var phys_dmg_addition: float = 0
@export var mag_dmg_addition: float = 0
@export var phys_dmg_multiplier: float = 1.0
@export var mag_dmg_multiplier: float = 1.0
@export var all_dmg_multiplier: float = 1.0
@export var is_vulnerable: bool = false
@export var is_weakened: bool = false

# ==== 常量 ====
const VULNERABILITY_EFFECT: float = 1.5
const WEAKNESS_EFFECT: float = 0.75

# ==== 计算属性（只读） ====
# 最大值的计算考虑各种加成
var max_hp: float:
	get:
		return base_max_hp  # 可以在这里添加生命值加成

var max_mp: float:
	get:
		return base_max_mp  # 可以在这里添加魔力加成

var max_ep: float:
	get:
		return base_max_ep  # 可以在这里添加能量加成

var defense: float:
	get:
		return base_def  # 可以在这里添加防御加成

var resistance: float:
	get:
		return base_res  # 可以在这里加法抗加成

# ==== 信号 ====
signal hp_changed(old_value: float, new_value: float)
signal mp_changed(old_value: float, new_value: float)
signal ep_changed(old_value: float, new_value: float)
signal shield_changed(old_value: float, new_value: float)
signal stat_changed(stat_name: String, old_value: float, new_value: float)

# ==== 初始化 ====
func _init():
	if character_id.is_empty():
		character_id = "char_%s" % randi()

# ==== 数值设置方法（确保在合法范围内） ====
func set_hp(value: float) -> void:
	var old_value = current_hp
	current_hp = clamp(value, 0, max_hp)
	if old_value != current_hp:
		hp_changed.emit(old_value, current_hp)
		stat_changed.emit("hp", old_value, current_hp)

func set_mp(value: float) -> void:
	var old_value = current_mp
	current_mp = clamp(value, 0, max_mp)
	if old_value != current_mp:
		mp_changed.emit(old_value, current_mp)
		stat_changed.emit("mp", old_value, current_mp)

func set_ep(value: float) -> void:
	var old_value = current_ep
	current_ep = clamp(value, 0, max_ep)
	if old_value != current_ep:
		ep_changed.emit(old_value, current_ep)
		stat_changed.emit("ep", old_value, current_ep)

func set_shield(value: float) -> void:
	var old_value = shield
	shield = max(0, value)
	if old_value != shield:
		shield_changed.emit(old_value, shield)
		stat_changed.emit("shield", old_value, shield)

# ==== 增减方法 ====
func add_hp(amount: float) -> void:
	set_hp(current_hp + amount)

func add_mp(amount: float) -> void:
	set_mp(current_mp + amount)

func add_ep(amount: float) -> void:
	set_ep(current_ep + amount)

func add_shield(amount: float) -> void:
	set_shield(shield + amount)

# ==== 伤害计算 ====
func take_damage(base_damage: float, damage_type: DamageType.Type) -> Dictionary:
	var final_damage: float = 0
	var damage_taken: float = 0
	var shield_used: float = 0
	
	match damage_type:
		DamageType.Type.PHYSICAL:
			final_damage = _calculate_physical_damage(base_damage)
		DamageType.Type.MAGIC:
			final_damage = _calculate_magic_damage(base_damage)
		DamageType.Type.TRUE:
			final_damage = _calculate_true_damage(base_damage)
	
	# 先计算护盾
	if shield > 0 and final_damage > 0:
		if shield >= final_damage:
			shield_used = final_damage
			set_shield(shield - final_damage)
			final_damage = 0
		else:
			shield_used = shield
			final_damage -= shield
			set_shield(0)
	
	# 剩余伤害扣血
	if final_damage > 0:
		damage_taken = final_damage
		set_hp(current_hp - final_damage)
	
	return {
		"total_damage": base_damage,
		"final_damage": final_damage + shield_used,
		"damage_taken": damage_taken,
		"shield_used": shield_used,
		"remaining_hp": current_hp,
		"remaining_shield": shield
	}

func _calculate_physical_damage(base_damage: float) -> float:
	# 物理伤害 = ((伤害数值 * 物理伤害倍率 * 伤害增加倍率) + 物理伤害加成) - 防御
	var damage = ((base_damage * phys_dmg_multiplier * all_dmg_multiplier) + phys_dmg_addition) - base_def
	damage = max(0, damage)
	damage = _apply_vulnerability_weakness(damage)
	return round(damage)

func _calculate_magic_damage(base_damage: float) -> float:
	# 法术伤害 = (((伤害数值 * 法术伤害倍率 * 伤害增加倍率) + 法术伤害加成) * (100 - 法抗) / 100)
	var damage = ((base_damage * mag_dmg_multiplier * all_dmg_multiplier) + mag_dmg_addition) * (100 - base_res) / 100
	damage = max(0, damage)
	damage = _apply_vulnerability_weakness(damage)
	return round(damage)

func _calculate_true_damage(base_damage: float) -> float:
	# 真实伤害 = 伤害数值 * 伤害增加倍率
	var damage = base_damage * all_dmg_multiplier
	damage = max(0, damage)
	damage = _apply_vulnerability_weakness(damage)
	return round(damage)

func _apply_vulnerability_weakness(damage: float) -> float:
	if is_vulnerable:
		damage *= VULNERABILITY_EFFECT
	if is_weakened:
		damage *= WEAKNESS_EFFECT
	return damage

# ==== 检查魔法类型 ====
func has_magic_type(type: MagicType.Type) -> bool:
	return type in magic_types

func add_magic_type(type: MagicType.Type) -> void:
	if not has_magic_type(type):
		magic_types.append(type)

func remove_magic_type(type: MagicType.Type) -> void:
	var index = magic_types.find(type)
	if index != -1:
		magic_types.remove_at(index)

# ==== 重置状态 ====
func reset_temporary_buffs() -> void:
	# 重置临时增益/减益
	phys_dmg_addition = 0
	mag_dmg_addition = 0
	phys_dmg_multiplier = 1.0
	mag_dmg_multiplier = 1.0
	all_dmg_multiplier = 1.0
	is_vulnerable = false
	is_weakened = false

# ==== 保存/加载 ====
func save_to_dict() -> Dictionary:
	return {
		"character_id": character_id,
		"character_name": character_name,
		"magic_types": magic_types,
		"current_hp": current_hp,
		"current_mp": current_mp,
		"current_ep": current_ep,
		"shield": shield,
		"base_max_hp": base_max_hp,
		"base_def": base_def,
		"base_res": base_res,
		"base_max_mp": base_max_mp,
		"base_max_ep": base_max_ep
	}

func load_from_dict(data: Dictionary) -> void:
	if "character_id" in data: character_id = data.character_id
	if "character_name" in data: character_name = data.character_name
	if "magic_types" in data: magic_types = data.magic_types
	if "current_hp" in data: current_hp = data.current_hp
	if "current_mp" in data: current_mp = data.current_mp
	if "current_ep" in data: current_ep = data.current_ep
	if "shield" in data: shield = data.shield
	if "base_max_hp" in data: base_max_hp = data.base_max_hp
	if "base_def" in data: base_def = data.base_def
	if "base_res" in data: base_res = data.base_res
	if "base_max_mp" in data: base_max_mp = data.base_max_mp
	if "base_max_ep" in data: base_max_ep = data.base_max_ep
