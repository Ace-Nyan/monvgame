## ResistanceProfile — 战斗者的元素抗性档案
## 抗性数值含义：incoming_damage *= (1.0 - resistance)
##   resistance =  0.5  -> 减伤 50%
##   resistance =  0.0  -> 标准
##   resistance = -0.5  -> 弱点，多受 50% 伤害
class_name ResistanceProfile
extends Resource

@export var resistances: Dictionary = {
	Element.Type.FIRE: 0.0,
	Element.Type.WATER: 0.0,
	Element.Type.GRASS: 0.0,
}

func get_resistance(element: int) -> float:
	return resistances.get(element, 0.0)

func add_resistance(element: int, delta: float) -> void:
	var cur: float = resistances.get(element, 0.0)
	resistances[element] = clampf(cur + delta, -0.95, 0.95)

func clone() -> ResistanceProfile:
	var c := ResistanceProfile.new()
	c.resistances = resistances.duplicate(true)
	return c

## 应用到一次伤害值
func mitigate(amount: float, element: int) -> float:
	var r := get_resistance(element)
	return amount * (1.0 - r)
