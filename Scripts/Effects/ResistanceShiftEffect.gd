## ResistanceShiftEffect — 临时改变目标的抗性（本场战斗内）
class_name ResistanceShiftEffect
extends CardEffect

@export var shifts: Dictionary = { Element.Type.FIRE: -0.2 }
@export var target_self: bool = false

func apply(ctx: Dictionary) -> void:
	var target: Combatant
	if target_self:
		target = ctx.get("source")
	else:
		target = ctx.get("target")
	if target == null:
		return
	for k in shifts.keys():
		target.resistance.add_resistance(int(k), float(shifts[k]))

func describe() -> String:
	var parts: Array[String] = []
	for k in shifts.keys():
		var sign := "+" if float(shifts[k]) >= 0 else ""
		parts.append("%s抗 %s%d%%" % [Element.name_of(int(k)), sign, int(round(float(shifts[k]) * 100))])
	return ", ".join(parts)
