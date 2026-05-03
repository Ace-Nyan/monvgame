## Element — 元素枚举与克制关系
## 单一事实来源：所有元素 ID、命名、克制都集中于此。
## 克制：火 > 草 > 水 > 火
class_name Element
extends RefCounted

enum Type {
	NONE,
	FIRE,
	WATER,
	GRASS,
}

const NAMES := {
	Type.NONE: "无",
	Type.FIRE: "火",
	Type.WATER: "水",
	Type.GRASS: "草",
}

const COLORS := {
	Type.NONE: Color(0.7, 0.7, 0.7),
	Type.FIRE: Color(1.0, 0.4, 0.2),
	Type.WATER: Color(0.3, 0.6, 1.0),
	Type.GRASS: Color(0.4, 0.85, 0.4),
}

## 克制矩阵：attacker 对 defender 的伤害倍率
##   FIRE  -> GRASS = 2.0   (有效)
##   FIRE  -> WATER = 0.5   (无效)
##   WATER -> FIRE  = 2.0
##   WATER -> GRASS = 0.5
##   GRASS -> WATER = 2.0
##   GRASS -> FIRE  = 0.5
const MATCHUP := {
	Type.FIRE:  { Type.GRASS: 2.0, Type.WATER: 0.5 },
	Type.WATER: { Type.FIRE:  2.0, Type.GRASS: 0.5 },
	Type.GRASS: { Type.WATER: 2.0, Type.FIRE:  0.5 },
}

static func name_of(t: int) -> String:
	return NAMES.get(t, "?")

static func color_of(t: int) -> Color:
	return COLORS.get(t, Color.WHITE)

## 求 attacker 对 defender 的克制倍率（不含抗性）
static func matchup_multiplier(attacker: int, defender: int) -> float:
	if attacker == Type.NONE or defender == Type.NONE:
		return 1.0
	var row: Dictionary = MATCHUP.get(attacker, {})
	return row.get(defender, 1.0)
