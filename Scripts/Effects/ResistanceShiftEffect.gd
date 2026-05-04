## ResistanceShiftEffect — 下一次该元素伤害无视法抗（本场战斗内）
class_name ResistanceShiftEffect
extends CardEffect

@export var shifts: Dictionary = { Element.Type.FIRE: 0.3 }
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
		var pct := float(shifts[k]) * 100.0
		target.pending_ignore_magic_resist[int(k)] = pct

func describe() -> String:
	var parts: Array[String] = []
	for k in shifts.keys():
		var shift_value: float = float(shifts[k])
		parts.append("%s伤害无视法抗 %d%%" % [Element.name_of(int(k)), int(round(shift_value * 100.0))])
	return ", ".join(parts)
